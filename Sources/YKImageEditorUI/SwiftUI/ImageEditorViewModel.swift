import Combine
import UIKit
import YKImageEditorCore

@MainActor
final class ImageEditorViewModel: NSObject, ObservableObject {
    @Published private(set) var currentImage: UIImage
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published var selectedTool: EditorTool?
    @Published var selectedColorIndex = 0
    @Published var textInput = ""
    @Published var isTextEditorPresented = false
    @Published var isStickerPickerPresented = false
    @Published var isDiscardConfirmationPresented = false
    @Published var selectedPreset: BlendPreset = .warmColorBurn
    @Published var blendIntensity = 0.45
    @Published private(set) var filterThumbnails: [BlendPreset: UIImage] = [:]
    @Published private(set) var isProcessing = false
    @Published var liquifyRadius = 0.12 {
        didSet { syncLiquifyBrush() }
    }
    @Published var liquifyStrength = 0.5 {
        didSet { syncLiquifyBrush() }
    }

    let availableTools: [EditorTool]
    let stickers: [UIImage]
    let doodleColors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .white, .black
    ]

    var onFinish: ((ImageEditorResult) -> Void)?

    private let config: EditorConfig
    private let session: EditorSession
    private var canvasHost: EditorCanvasHostView?

    private var blendBaseImage: UIImage?
    private var blendPreviewBase: UIImage?
    private var cachedBlendEffect: UIImage?
    private var blendRenderGeneration = 0
    private var thumbnailGeneration = 0

    private var liquifySourceImage: UIImage?
    private let liquifyDeformer = LiquifyDeformer(columns: 56, rows: 56)
    private var liquifyStrokeStart: LiquifyDeformer?
    private var liquifyStrokeChanged = false
    private var liquifyHistoryStart: Int?

    private var undoActions: [EditorHistoryAction] = []
    private var redoActions: [EditorHistoryAction] = []

    init(image: UIImage, config: EditorConfig, stickerProvider: StickerProviding?) {
        let resolvedStickers = (stickerProvider?.stickersForEditor() ?? [])
            .map(StickerImageRendering.resolvedImage)
        self.config = config
        session = EditorSession(image: image, maxDimension: config.exportOptions.maxDimension)
        currentImage = session.currentImage
        stickers = resolvedStickers
        availableTools = EditorTool.allCases.filter { tool in
            guard config.isEnabled(tool.feature) else { return false }
            return tool != .sticker || !resolvedStickers.isEmpty
        }
        super.init()
        refreshHistoryState()
    }

    func makeCanvasHost() -> EditorCanvasHostView {
        if let canvasHost {
            return canvasHost
        }
        let host = EditorCanvasHostView()
        canvasHost = host
        host.brushView.delegate = self
        host.canvas.doodleView.onStrokeFinished = { [weak self] stroke in
            self?.recordHistory(.doodleStroke(stroke))
        }
        syncCanvas()
        return host
    }

    func selectTool(_ tool: EditorTool) {
        if selectedTool == .mosaic, tool != .mosaic {
            applyMosaicIfNeeded()
        }
        dismissTransientTool(except: tool)
        selectedTool = tool
        syncCanvasInteraction()

        switch tool {
        case .crop:
            break
        case .text:
            isTextEditorPresented = true
        case .sticker:
            isStickerPickerPresented = true
        case .blend:
            startBlend()
        case .liquify:
            startLiquify()
        case .doodle, .mosaic:
            break
        }
    }

    func selectDoodleColor(at index: Int) {
        guard doodleColors.indices.contains(index) else { return }
        selectedColorIndex = index
        canvasHost?.canvas.doodleView.strokeColor = doodleColors[index]
        if selectedTool == .text {
            isTextEditorPresented = true
        }
    }

    func addText() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        textInput = ""
        guard !text.isEmpty, let canvas = canvasHost?.canvas else { return }
        let color = doodleColors[selectedColorIndex]
        let overlay = OverlayFactory.textOverlay(text: text, color: color)
        overlay.center = CGPoint(
            x: canvas.overlayContainer.bounds.midX,
            y: canvas.overlayContainer.bounds.midY
        )
        addOverlay(overlay, to: canvas, recordHistory: true)
    }

    func addSticker(_ image: UIImage) {
        guard let canvas = canvasHost?.canvas else { return }
        let overlay = OverlayFactory.stickerOverlay(image: image)
        overlay.center = CGPoint(
            x: canvas.overlayContainer.bounds.midX,
            y: canvas.overlayContainer.bounds.midY
        )
        addOverlay(overlay, to: canvas, recordHistory: true)
        isStickerPickerPresented = false
    }

    func applyOverlayLayers() {
        selectedTool = nil
        syncCanvasInteraction()
    }

    func completeCrop(_ image: UIImage) {
        commit(image)
        selectedTool = nil
        syncCanvasInteraction()
    }

    func cancelCrop() {
        selectedTool = nil
        syncCanvasInteraction()
    }

    func undo() {
        if selectedTool == .blend {
            cancelBlend()
        }
        if selectedTool == .mosaic, canvasHost?.canvas.mosaicMaskView.hasContent == true {
            applyMosaicIfNeeded()
        }
        if selectedTool == .liquify, undoActions.last?.isLiquifyAction != true {
            cancelLiquify()
        }
        guard let action = undoActions.popLast() else { return }
        applyUndo(action)
        redoActions.append(action)
        refreshHistoryState()
        syncCanvasInteraction()
    }

    func redo() {
        if selectedTool == .blend {
            cancelBlend()
        }
        if selectedTool == .liquify, redoActions.last?.isLiquifyAction != true {
            cancelLiquify()
        }
        guard let action = redoActions.popLast() else { return }
        applyRedo(action)
        undoActions.append(action)
        refreshHistoryState()
        syncCanvasInteraction()
    }

    func requestClose() {
        let canvas = canvasHost?.canvas
        let hasOverlays = canvas?.overlayContainer.subviews.contains {
            !($0 is DoodleDrawView || $0 is MosaicMaskView)
        } ?? false
        let hasPendingLiquify = liquifySourceImage != nil && liquifyDeformer.hasDeformation
        if !undoActions.isEmpty || session.isDirty || hasOverlays
            || canvas?.doodleView.hasContent == true || canvas?.mosaicMaskView.hasContent == true
            || hasPendingLiquify {
            isDiscardConfirmationPresented = true
        } else {
            dismissTransientTool(except: nil)
            onFinish?(.cancelled)
        }
    }

    func discard() {
        onFinish?(.cancelled)
    }

    func export() {
        dismissTransientTool(except: nil)
        applyMosaicIfNeeded()
        let composed = canvasHost?.canvas.renderEditableLayers(onto: session.currentImage)
            ?? session.currentImage
        let exported = ImageExporter.export(composed, options: config.exportOptions)
        onFinish?(.finished(exported))
    }

    func setBlendIntensity(_ value: Double) {
        blendIntensity = value
        canvasHost?.canvas.setBlendPreview(
            effect: cachedBlendEffect,
            intensity: CGFloat(value)
        )
    }

    func selectPreset(_ preset: BlendPreset) {
        guard preset != selectedPreset || cachedBlendEffect == nil else { return }
        selectedPreset = preset
        cachedBlendEffect = nil
        rebuildBlendPreview()
    }

    func cancelBlend() {
        dismissBlend()
        selectedTool = nil
        syncCanvasInteraction()
    }

    func applyBlend() {
        guard let base = blendBaseImage else { return }
        isProcessing = true
        let preset = selectedPreset
        let intensity = CGFloat(blendIntensity)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = ImageBlender.blend(base: base, preset: preset, intensity: intensity)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isProcessing = false
                self.dismissBlend()
                self.commit(result)
                self.selectedTool = nil
                self.syncCanvasInteraction()
            }
        }
    }

    func resetLiquify() {
        guard liquifyDeformer.hasDeformation else { return }
        let before = liquifyDeformer.snapshot()
        liquifyDeformer.reset()
        recordHistory(.liquifyStroke(before: before, after: liquifyDeformer.snapshot()))
        canvasHost?.canvas.updateLiquifyPreview(deformer: liquifyDeformer)
    }

    func cancelLiquify() {
        discardLiquifyHistory()
        dismissLiquify()
        selectedTool = nil
        syncCanvasInteraction()
    }

    func applyLiquify() {
        guard let source = liquifySourceImage else { return }
        guard liquifyDeformer.hasDeformation else {
            cancelLiquify()
            return
        }
        isProcessing = true
        canvasHost?.brushView.setActive(false)
        let snapshot = UncheckedSendableValue(liquifyDeformer.snapshot())
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = LiquifyProcessor.render(image: source, deformer: snapshot.value, maxDimension: 0)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isProcessing = false
                self.discardLiquifyHistory()
                self.dismissLiquify()
                self.commit(result)
                self.selectedTool = nil
                self.syncCanvasInteraction()
            }
        }
    }

    private func startBlend() {
        blendBaseImage = session.currentImage
        blendPreviewBase = ImageGeometry.downsample(session.currentImage, maxDimension: 1080)
        cachedBlendEffect = nil
        rebuildFilterThumbnails()
        rebuildBlendPreview()
    }

    private func rebuildFilterThumbnails() {
        guard let previewBase = blendPreviewBase else { return }
        thumbnailGeneration += 1
        let generation = thumbnailGeneration
        let source = ImageGeometry.downsample(previewBase, maxDimension: 160)
        let presets = BlendPreset.allCases
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var images: [BlendPreset: UIImage] = [:]
            for preset in presets {
                let overlay = preset.makeOverlayImage(size: source.size, scale: source.scale)
                images[preset] = ImageBlender.blend(
                    base: source,
                    overlay: overlay,
                    mode: preset.mode,
                    opacity: 0.7
                )
            }
            DispatchQueue.main.async {
                guard let self, generation == self.thumbnailGeneration else { return }
                self.filterThumbnails = images
            }
        }
    }

    private func rebuildBlendPreview() {
        guard let previewBase = blendPreviewBase else { return }
        blendRenderGeneration += 1
        let generation = blendRenderGeneration
        let preset = selectedPreset
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let overlay = preset.makeOverlayImage(size: previewBase.size, scale: previewBase.scale)
            let effect = ImageBlender.blendFully(base: previewBase, overlay: overlay, mode: preset.mode)
            DispatchQueue.main.async {
                guard let self, generation == self.blendRenderGeneration else { return }
                self.cachedBlendEffect = effect
                self.isProcessing = false
                self.canvasHost?.canvas.setBlendPreview(effect: effect, intensity: CGFloat(self.blendIntensity))
            }
        }
    }

    private func dismissBlend() {
        blendRenderGeneration += 1
        thumbnailGeneration += 1
        blendBaseImage = nil
        blendPreviewBase = nil
        cachedBlendEffect = nil
        filterThumbnails = [:]
        canvasHost?.canvas.setBlendPreview(effect: nil, intensity: 0)
    }

    private func startLiquify() {
        liquifySourceImage = session.currentImage
        liquifyDeformer.reset()
        liquifyHistoryStart = undoActions.count
        liquifyStrokeStart = nil
        liquifyStrokeChanged = false
        canvasHost?.canvas.beginLiquifyPreview(
            image: session.currentImage,
            deformer: liquifyDeformer
        )
        syncLiquifyBrush()
    }

    private func dismissLiquify() {
        liquifySourceImage = nil
        liquifyDeformer.reset()
        liquifyStrokeStart = nil
        liquifyStrokeChanged = false
        liquifyHistoryStart = nil
        canvasHost?.canvas.endLiquifyPreview()
        canvasHost?.brushView.setActive(false)
    }

    private func dismissTransientTool(except tool: EditorTool?) {
        if tool != .blend, blendBaseImage != nil {
            dismissBlend()
        }
        if tool != .liquify, liquifySourceImage != nil {
            discardLiquifyHistory()
            dismissLiquify()
        }
        isProcessing = false
    }

    private func applyMosaicIfNeeded() {
        guard let canvas = canvasHost?.canvas else { return }
        if canvas.mosaicMaskView.hasContent,
           let mask = canvas.mosaicMaskView.makeMaskImage(
               size: session.currentImage.size,
               scale: session.currentImage.scale
           ) {
            let blockSize = max(8, Int(session.currentImage.size.width / 60))
            canvas.mosaicMaskView.clear()
            commit(MosaicProcessor.pixelate(session.currentImage, blockSize: blockSize, mask: mask))
        }
    }

    private func addOverlay(
        _ overlay: TransformableOverlayView,
        to canvas: EditorCanvasView,
        recordHistory shouldRecord: Bool
    ) {
        overlay.onTransformFinished = { [weak self] overlay, before, after in
            self?.recordHistory(.overlayTransform(overlay: overlay, before: before, after: after))
        }
        canvas.overlayContainer.addSubview(overlay)
        if shouldRecord {
            recordHistory(.overlayAdded(overlay))
        }
    }

    private func recordHistory(_ action: EditorHistoryAction) {
        undoActions.append(action)
        redoActions.removeAll()
        refreshHistoryState()
    }

    private func applyUndo(_ action: EditorHistoryAction) {
        switch action {
        case .bitmapCheckpoint:
            if let image = session.undo() {
                updateCurrentImage(image)
            }
        case .doodleStroke(let stroke):
            canvasHost?.canvas.doodleView.removeStroke(id: stroke.id)
        case .overlayAdded(let overlay):
            overlay.removeFromSuperview()
        case .overlayTransform(let overlay, let before, _):
            overlay.restoreTransformState(before)
        case .liquifyStroke(let before, _):
            liquifyDeformer.restore(from: before)
            refreshLiquifyPreviewAfterHistoryChange()
        }
    }

    private func applyRedo(_ action: EditorHistoryAction) {
        switch action {
        case .bitmapCheckpoint:
            if let image = session.redo() {
                updateCurrentImage(image)
            }
        case .doodleStroke(let stroke):
            canvasHost?.canvas.doodleView.restoreStroke(stroke)
        case .overlayAdded(let overlay):
            guard let canvas = canvasHost?.canvas else { return }
            addOverlay(overlay, to: canvas, recordHistory: false)
        case .overlayTransform(let overlay, _, let after):
            overlay.restoreTransformState(after)
        case .liquifyStroke(_, let after):
            liquifyDeformer.restore(from: after)
            refreshLiquifyPreviewAfterHistoryChange()
        }
    }

    private func refreshLiquifyPreviewAfterHistoryChange() {
        guard selectedTool == .liquify else { return }
        canvasHost?.canvas.updateLiquifyPreview(deformer: liquifyDeformer)
    }

    private func discardLiquifyHistory() {
        if let start = liquifyHistoryStart, start < undoActions.count {
            undoActions.removeSubrange(start...)
        }
        redoActions.removeAll(where: \.isLiquifyAction)
        liquifyHistoryStart = nil
        refreshHistoryState()
    }

    private func commit(_ image: UIImage) {
        session.commit(image)
        recordHistory(.bitmapCheckpoint)
        updateCurrentImage(session.currentImage)
    }

    private func updateCurrentImage(_ image: UIImage) {
        currentImage = image
        canvasHost?.canvas.setImage(image)
        refreshHistoryState()
    }

    private func refreshHistoryState() {
        canUndo = !undoActions.isEmpty
        canRedo = !redoActions.isEmpty
    }

    private func syncCanvas() {
        canvasHost?.canvas.setImage(currentImage)
        canvasHost?.canvas.doodleView.strokeColor = doodleColors[selectedColorIndex]
        syncCanvasInteraction()
    }

    private func syncCanvasInteraction() {
        guard let host = canvasHost else { return }
        let isDoodle = selectedTool == .doodle
        let isMosaic = selectedTool == .mosaic
        host.canvas.doodleView.isHidden = !isDoodle && !host.canvas.doodleView.hasContent
        host.canvas.doodleView.isUserInteractionEnabled = isDoodle
        host.canvas.mosaicMaskView.isHidden = !isMosaic
        host.canvas.mosaicMaskView.isUserInteractionEnabled = isMosaic
        host.brushView.setActive(selectedTool == .liquify)
    }

    private func syncLiquifyBrush() {
        canvasHost?.brushView.mode = .push
        canvasHost?.brushView.brushRadiusRatio = CGFloat(liquifyRadius)
        canvasHost?.brushView.strength = CGFloat(liquifyStrength)
    }
}

extension ImageEditorViewModel: LiquifyBrushViewDelegate {
    func liquifyBrushViewRequestImageFrame(_ view: LiquifyBrushView) -> CGRect {
        guard let canvas = canvasHost?.canvas else { return .zero }
        return canvas.convert(canvas.imageFrame, to: view)
    }

    func liquifyBrushViewWillBeginStroke(_ view: LiquifyBrushView) {
        guard !isProcessing else { return }
        liquifyStrokeStart = liquifyDeformer.snapshot()
        liquifyStrokeChanged = false
    }

    func liquifyBrushView(
        _ view: LiquifyBrushView,
        didStroke mode: LiquifyMode,
        at point: CGPoint,
        delta: CGPoint,
        radius: CGFloat,
        strength: CGFloat
    ) {
        guard !isProcessing else { return }
        let frame = liquifyBrushViewRequestImageFrame(view)
        let aspectRatio = frame.height > 0 ? frame.width / frame.height : 1
        liquifyDeformer.apply(
            mode: mode,
            at: point,
            delta: delta,
            radius: radius,
            strength: strength,
            aspectRatio: aspectRatio
        )
        liquifyStrokeChanged = true
        canvasHost?.canvas.updateLiquifyPreview(deformer: liquifyDeformer)
    }

    func liquifyBrushViewDidEndStroke(_ view: LiquifyBrushView) {
        if liquifyStrokeChanged, let before = liquifyStrokeStart {
            recordHistory(.liquifyStroke(before: before, after: liquifyDeformer.snapshot()))
        }
        liquifyStrokeStart = nil
        liquifyStrokeChanged = false
    }
}

private enum EditorHistoryAction {
    case bitmapCheckpoint
    case doodleStroke(DoodleStroke)
    case overlayAdded(TransformableOverlayView)
    case overlayTransform(
        overlay: TransformableOverlayView,
        before: OverlayTransformState,
        after: OverlayTransformState
    )
    case liquifyStroke(before: LiquifyDeformer, after: LiquifyDeformer)

    var isLiquifyAction: Bool {
        if case .liquifyStroke = self { return true }
        return false
    }
}

final class EditorCanvasHostView: UIView {
    let canvas = EditorCanvasView()
    let brushView = LiquifyBrushView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        addSubview(canvas)
        addSubview(brushView)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        brushView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: topAnchor),
            canvas.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: bottomAnchor),
            brushView.topAnchor.constraint(equalTo: topAnchor),
            brushView.leadingAnchor.constraint(equalTo: leadingAnchor),
            brushView.trailingAnchor.constraint(equalTo: trailingAnchor),
            brushView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class UncheckedSendableValue<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

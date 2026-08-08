import UIKit
import YKImageEditorCore

/// 图片编辑会话控制器（醒图式深色工具栏）。
///
/// 通过 ``UIViewController/yk_presentImageEditor(image:config:stickerProvider:animated:completion:)``
/// 或直接初始化后由宿主 `present` / `push`。
///
/// `completion` **始终在主线程**回调。
public final class ImageEditorViewController: UIViewController {
    private let config: EditorConfig
    private let stickerProvider: StickerProviding?
    private let completion: (ImageEditorResult) -> Void
    private let session: EditorSession

    private let canvas = EditorCanvasView()
    private let topBar = UIView()
    private let dock = UIView()
    private let secondaryHost = UIView()
    private let categoryBar = ToolCategoryBar()
    private let blendPanel = BlendToolPanel()
    private let liquifyPanel = LiquifyToolPanel()
    private let liquifyBrushView = LiquifyBrushView()
    private let colorStack = UIStackView()
    private let colorHost = UIView()
    private var selectedTool: EditorTool?
    private var availableTools: [EditorTool] = []
    private var secondaryHeightConstraint: NSLayoutConstraint?

    private let doodleColors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .white, .black
    ]

    public init(
        image: UIImage,
        config: EditorConfig = .all,
        stickerProvider: StickerProviding? = nil,
        completion: @escaping (ImageEditorResult) -> Void
    ) {
        self.config = config
        self.stickerProvider = stickerProvider
        self.completion = completion
        self.session = EditorSession(
            image: image,
            maxDimension: config.exportOptions.maxDimension
        )
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = EditorTheme.background
        configureTools()
        buildLayout()
        canvas.setImage(session.currentImage)
        selectTool(nil)
    }

    private func configureTools() {
        availableTools = EditorTool.allCases.filter { tool in
            guard config.isEnabled(tool.feature) else { return false }
            if tool == .sticker {
                let stickers = stickerProvider?.stickersForEditor() ?? []
                return !stickers.isEmpty
            }
            return true
        }
    }

    private func buildLayout() {
        view.addSubview(canvas)
        view.addSubview(liquifyBrushView)
        view.addSubview(topBar)
        view.addSubview(dock)

        dock.backgroundColor = EditorTheme.panel
        secondaryHost.backgroundColor = EditorTheme.panel
        secondaryHost.clipsToBounds = true

        dock.addSubview(secondaryHost)
        dock.addSubview(categoryBar)
        secondaryHost.addSubview(colorHost)
        secondaryHost.addSubview(blendPanel)
        secondaryHost.addSubview(liquifyPanel)

        canvas.translatesAutoresizingMaskIntoConstraints = false
        liquifyBrushView.translatesAutoresizingMaskIntoConstraints = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        dock.translatesAutoresizingMaskIntoConstraints = false
        secondaryHost.translatesAutoresizingMaskIntoConstraints = false
        categoryBar.translatesAutoresizingMaskIntoConstraints = false
        colorHost.translatesAutoresizingMaskIntoConstraints = false
        blendPanel.translatesAutoresizingMaskIntoConstraints = false
        liquifyPanel.translatesAutoresizingMaskIntoConstraints = false

        blendPanel.delegate = self
        liquifyPanel.delegate = self
        liquifyBrushView.delegate = self
        categoryBar.delegate = self
        categoryBar.configure(tools: availableTools)

        buildTopBar()
        buildColorHost()

        let secondaryHeight = secondaryHost.heightAnchor.constraint(equalToConstant: 0)
        secondaryHeightConstraint = secondaryHeight

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: EditorTheme.topBarHeight),

            dock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dock.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dock.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            categoryBar.leadingAnchor.constraint(equalTo: dock.leadingAnchor),
            categoryBar.trailingAnchor.constraint(equalTo: dock.trailingAnchor),
            categoryBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            categoryBar.heightAnchor.constraint(equalToConstant: EditorTheme.categoryHeight),

            secondaryHost.leadingAnchor.constraint(equalTo: dock.leadingAnchor),
            secondaryHost.trailingAnchor.constraint(equalTo: dock.trailingAnchor),
            secondaryHost.bottomAnchor.constraint(equalTo: categoryBar.topAnchor),
            secondaryHost.topAnchor.constraint(equalTo: dock.topAnchor),
            secondaryHeight,

            canvas.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: dock.topAnchor),

            liquifyBrushView.topAnchor.constraint(equalTo: canvas.topAnchor),
            liquifyBrushView.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            liquifyBrushView.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            liquifyBrushView.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),

            colorHost.topAnchor.constraint(equalTo: secondaryHost.topAnchor),
            colorHost.leadingAnchor.constraint(equalTo: secondaryHost.leadingAnchor),
            colorHost.trailingAnchor.constraint(equalTo: secondaryHost.trailingAnchor),
            colorHost.bottomAnchor.constraint(equalTo: secondaryHost.bottomAnchor),

            blendPanel.topAnchor.constraint(equalTo: secondaryHost.topAnchor),
            blendPanel.leadingAnchor.constraint(equalTo: secondaryHost.leadingAnchor),
            blendPanel.trailingAnchor.constraint(equalTo: secondaryHost.trailingAnchor),
            blendPanel.bottomAnchor.constraint(equalTo: secondaryHost.bottomAnchor),

            liquifyPanel.topAnchor.constraint(equalTo: secondaryHost.topAnchor),
            liquifyPanel.leadingAnchor.constraint(equalTo: secondaryHost.leadingAnchor),
            liquifyPanel.trailingAnchor.constraint(equalTo: secondaryHost.trailingAnchor),
            liquifyPanel.bottomAnchor.constraint(equalTo: secondaryHost.bottomAnchor)
        ])
    }

    private func buildTopBar() {
        topBar.backgroundColor = EditorTheme.panel

        let cancel = UIButton(type: .system)
        let closeConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        cancel.setImage(UIImage(systemName: "xmark", withConfiguration: closeConfig), for: .normal)
        cancel.tintColor = EditorTheme.primaryText
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let undo = UIButton(type: .system)
        undo.setImage(UIImage(systemName: "arrow.uturn.backward", withConfiguration: closeConfig), for: .normal)
        undo.tintColor = EditorTheme.primaryText
        undo.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)

        let redo = UIButton(type: .system)
        redo.setImage(UIImage(systemName: "arrow.uturn.forward", withConfiguration: closeConfig), for: .normal)
        redo.tintColor = EditorTheme.primaryText
        redo.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)

        let done = UIButton(type: .system)
        done.setTitle("导出", for: .normal)
        done.setTitleColor(EditorTheme.accentText, for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        done.backgroundColor = EditorTheme.accent
        done.layer.cornerRadius = 16
        done.contentEdgeInsets = UIEdgeInsets(top: 7, left: 16, bottom: 7, right: 16)
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        [cancel, undo, redo, done].forEach {
            topBar.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            cancel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 14),
            cancel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            cancel.widthAnchor.constraint(equalToConstant: 36),
            cancel.heightAnchor.constraint(equalToConstant: 36),

            undo.leadingAnchor.constraint(equalTo: cancel.trailingAnchor, constant: 8),
            undo.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            undo.widthAnchor.constraint(equalToConstant: 36),
            undo.heightAnchor.constraint(equalToConstant: 36),

            redo.leadingAnchor.constraint(equalTo: undo.trailingAnchor, constant: 2),
            redo.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            redo.widthAnchor.constraint(equalToConstant: 36),
            redo.heightAnchor.constraint(equalToConstant: 36),

            done.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -14),
            done.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])
    }

    private func buildColorHost() {
        colorHost.backgroundColor = EditorTheme.panel
        colorHost.isHidden = true

        colorStack.axis = .horizontal
        colorStack.spacing = 12
        colorStack.alignment = .center
        colorStack.distribution = .equalSpacing

        for (index, color) in doodleColors.enumerated() {
            let button = UIButton(type: .custom)
            button.backgroundColor = color
            button.layer.cornerRadius = 13
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
            button.tag = index
            button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 26),
                button.heightAnchor.constraint(equalToConstant: 26)
            ])
            colorStack.addArrangedSubview(button)
        }

        let applyButton = UIButton(type: .system)
        applyButton.setTitle("应用图层", for: .normal)
        applyButton.setTitleColor(EditorTheme.accentText, for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        applyButton.backgroundColor = EditorTheme.accent
        applyButton.layer.cornerRadius = 14
        applyButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        applyButton.addTarget(self, action: #selector(applyOverlaysTapped), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [colorStack, applyButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 16
        colorHost.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: colorHost.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(lessThanOrEqualTo: colorHost.trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: colorHost.centerYAnchor)
        ])
    }

    private func setSecondaryHeight(_ height: CGFloat) {
        secondaryHeightConstraint?.constant = height
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }

    private func selectTool(_ tool: EditorTool?) {
        dismissTransientPanels(except: tool)

        selectedTool = tool
        categoryBar.select(tool)
        canvas.doodleView.isHidden = tool != .doodle
        canvas.mosaicMaskView.isHidden = tool != .mosaic
        canvas.doodleView.isUserInteractionEnabled = tool == .doodle
        canvas.mosaicMaskView.isUserInteractionEnabled = tool == .mosaic
        liquifyBrushView.setActive(tool == .liquify)

        let showColors = tool == .doodle || tool == .text
        colorHost.isHidden = !showColors

        if tool == .crop {
            setSecondaryHeight(0)
            presentCrop()
        } else if tool == .text {
            setSecondaryHeight(52)
            promptText()
        } else if tool == .sticker {
            setSecondaryHeight(0)
            presentStickers()
        } else if tool == .blend {
            presentBlend()
        } else if tool == .liquify {
            presentLiquify()
        } else if tool == .doodle {
            setSecondaryHeight(52)
        } else if tool == .mosaic {
            setSecondaryHeight(0)
        } else {
            setSecondaryHeight(0)
        }
    }

    private func dismissTransientPanels(except tool: EditorTool?) {
        if tool != .blend, !blendPanel.isHidden {
            blendPanel.dismissPanel()
            canvas.setBlendPreview(effect: nil, intensity: 0)
        }
        if tool != .liquify, !liquifyPanel.isHidden {
            liquifyPanel.dismissPanel()
            liquifyBrushView.setActive(false)
            canvas.setPreviewImage(nil)
        }
        if tool != .doodle, tool != .text {
            colorHost.isHidden = true
        }
    }

    private func presentBlend() {
        applyTransientDrawingIfNeeded()
        flattenTransformableOverlays()
        colorHost.isHidden = true
        liquifyPanel.isHidden = true
        setSecondaryHeight(148)
        blendPanel.present(with: session.currentImage)
    }

    private func presentLiquify() {
        applyTransientDrawingIfNeeded()
        flattenTransformableOverlays()
        colorHost.isHidden = true
        blendPanel.isHidden = true
        setSecondaryHeight(132)
        liquifyBrushView.setActive(true)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        liquifyPanel.present(with: session.currentImage)
    }

    @objc private func colorTapped(_ sender: UIButton) {
        let color = doodleColors[sender.tag]
        canvas.doodleView.strokeColor = color
        if selectedTool == .text {
            promptText(defaultColor: color)
        }
    }

    @objc private func applyOverlaysTapped() {
        applyTransientDrawingIfNeeded()
        flattenTransformableOverlays()
    }

    private func applyTransientDrawingIfNeeded() {
        if selectedTool == .doodle, canvas.doodleView.hasContent {
            commitDoodleOnly()
        } else if selectedTool == .mosaic, canvas.mosaicMaskView.hasContent {
            commitMosaic()
        }
    }

    private func commitDoodleOnly() {
        guard canvas.doodleView.hasContent,
              let doodle = canvas.doodleView.snapshotImage() else { return }
        let base = session.currentImage
        let size = base.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let result = renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
            doodle.draw(in: CGRect(origin: .zero, size: size))
        }
        session.commit(result)
        canvas.doodleView.clear()
        canvas.setImage(session.currentImage)
    }

    private func commitMosaic() {
        guard let mask = canvas.mosaicMaskView.makeMaskImage(
            size: session.currentImage.size,
            scale: session.currentImage.scale
        ) else { return }
        let block = max(8, Int(session.currentImage.size.width / 60))
        let result = MosaicProcessor.pixelate(session.currentImage, blockSize: block, mask: mask)
        session.commit(result)
        canvas.mosaicMaskView.clear()
        canvas.setImage(session.currentImage)
    }

    private func flattenTransformableOverlays() {
        let hasOverlays = canvas.overlayContainer.subviews.contains {
            !($0 is DoodleDrawView || $0 is MosaicMaskView) && !$0.isHidden
        }
        guard hasOverlays else { return }
        let doodleHidden = canvas.doodleView.isHidden
        let mosaicHidden = canvas.mosaicMaskView.isHidden
        canvas.doodleView.isHidden = true
        canvas.mosaicMaskView.isHidden = true
        let merged = canvas.flattenOverlays(onto: session.currentImage)
        canvas.doodleView.isHidden = doodleHidden
        canvas.mosaicMaskView.isHidden = mosaicHidden
        session.commit(merged)
        canvas.clearTransientOverlays()
        canvas.setImage(session.currentImage)
        canvas.doodleView.isHidden = selectedTool != .doodle
        canvas.mosaicMaskView.isHidden = selectedTool != .mosaic
    }

    private func promptText(defaultColor: UIColor = .white) {
        let alert = UIAlertController(title: "添加文字", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "输入文字" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "添加", style: .default) { [weak self] _ in
            guard let self,
                  let text = alert.textFields?.first?.text,
                  !text.isEmpty else { return }
            let overlay = OverlayFactory.textOverlay(text: text, color: defaultColor)
            overlay.center = CGPoint(
                x: self.canvas.overlayContainer.bounds.midX,
                y: self.canvas.overlayContainer.bounds.midY
            )
            self.canvas.overlayContainer.addSubview(overlay)
        })
        present(alert, animated: true)
    }

    private func presentStickers() {
        let stickers = stickerProvider?.stickersForEditor() ?? []
        guard !stickers.isEmpty else { return }
        let sheet = UIAlertController(title: "选择贴纸", message: nil, preferredStyle: .actionSheet)
        for (index, image) in stickers.enumerated() {
            sheet.addAction(UIAlertAction(title: "贴纸 \(index + 1)", style: .default) { [weak self] _ in
                guard let self else { return }
                let overlay = OverlayFactory.stickerOverlay(image: image)
                overlay.center = CGPoint(
                    x: self.canvas.overlayContainer.bounds.midX,
                    y: self.canvas.overlayContainer.bounds.midY
                )
                self.canvas.overlayContainer.addSubview(overlay)
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = categoryBar
            pop.sourceRect = categoryBar.bounds
        }
        present(sheet, animated: true)
    }

    private func presentCrop() {
        applyTransientDrawingIfNeeded()
        flattenTransformableOverlays()
        let crop = CropToolViewController(image: session.currentImage)
        crop.delegate = self
        present(crop, animated: true)
    }

    @objc private func undoTapped() {
        dismissTransientPanels(except: nil)
        applyTransientDrawingIfNeeded()
        if let image = session.undo() {
            canvas.clearTransientOverlays()
            canvas.setImage(image)
        }
        setSecondaryHeight(selectedTool == .doodle || selectedTool == .text ? 52 : 0)
    }

    @objc private func redoTapped() {
        dismissTransientPanels(except: nil)
        if let image = session.redo() {
            canvas.clearTransientOverlays()
            canvas.setImage(image)
        }
        setSecondaryHeight(selectedTool == .doodle || selectedTool == .text ? 52 : 0)
    }

    @objc private func cancelTapped() {
        dismissTransientPanels(except: nil)
        applyTransientDrawingIfNeeded()
        let hasOverlays = canvas.overlayContainer.subviews.contains {
            !($0 is DoodleDrawView || $0 is MosaicMaskView)
        }
        if session.isDirty || hasOverlays || canvas.doodleView.hasContent || canvas.mosaicMaskView.hasContent {
            let alert = UIAlertController(
                title: "放弃编辑？",
                message: "退出后将丢失当前修改",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "继续编辑", style: .cancel))
            alert.addAction(UIAlertAction(title: "放弃", style: .destructive) { [weak self] _ in
                self?.finish(.cancelled)
            })
            present(alert, animated: true)
        } else {
            finish(.cancelled)
        }
    }

    @objc private func doneTapped() {
        dismissTransientPanels(except: nil)
        applyTransientDrawingIfNeeded()
        flattenTransformableOverlays()
        let exported = session.makeExportImage(options: config.exportOptions)
        finish(.finished(exported))
    }

    private func finish(_ result: ImageEditorResult) {
        let deliver = { [completion] in
            completion(result)
        }
        let dismissAndDeliver = { [weak self] in
            guard let self else {
                DispatchQueue.main.async(execute: deliver)
                return
            }
            if self.presentingViewController != nil {
                self.dismiss(animated: true) {
                    DispatchQueue.main.async(execute: deliver)
                }
            } else if let nav = self.navigationController, nav.topViewController === self {
                nav.popViewController(animated: true)
                DispatchQueue.main.async(execute: deliver)
            } else {
                DispatchQueue.main.async(execute: deliver)
            }
        }
        if Thread.isMainThread {
            dismissAndDeliver()
        } else {
            DispatchQueue.main.async(execute: dismissAndDeliver)
        }
    }
}

extension ImageEditorViewController: ToolCategoryBarDelegate {
    func toolCategoryBar(_ bar: ToolCategoryBar, didSelect tool: EditorTool) {
        if selectedTool == .doodle || selectedTool == .mosaic {
            applyTransientDrawingIfNeeded()
        }
        selectTool(tool)
    }
}

extension ImageEditorViewController: CropToolViewControllerDelegate {
    func cropTool(_ controller: CropToolViewController, didFinish image: UIImage) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.session.commit(image)
            self.canvas.setImage(self.session.currentImage)
            self.selectTool(nil)
        }
    }

    func cropToolDidCancel(_ controller: CropToolViewController) {
        controller.dismiss(animated: true) { [weak self] in
            self?.selectTool(nil)
        }
    }
}

extension ImageEditorViewController: BlendToolPanelDelegate {
    func blendToolPanel(_ panel: BlendToolPanel, didUpdatePreview effect: UIImage?, intensity: CGFloat) {
        canvas.setBlendPreview(effect: effect, intensity: intensity)
    }

    func blendToolPanel(_ panel: BlendToolPanel, didApply image: UIImage) {
        session.commit(image)
        canvas.setBlendPreview(effect: nil, intensity: 0)
        canvas.setImage(session.currentImage)
        setSecondaryHeight(0)
        selectTool(availableTools.first { $0 != .blend })
    }

    func blendToolPanelDidCancel(_ panel: BlendToolPanel) {
        canvas.setBlendPreview(effect: nil, intensity: 0)
        setSecondaryHeight(0)
        selectTool(availableTools.first { $0 != .blend })
    }
}

extension ImageEditorViewController: LiquifyToolPanelDelegate {
    func liquifyToolPanel(_ panel: LiquifyToolPanel, didUpdatePreview image: UIImage?) {
        canvas.setBlendPreview(effect: image, intensity: image == nil ? 0 : 1)
    }

    func liquifyToolPanel(_ panel: LiquifyToolPanel, didApply image: UIImage) {
        session.commit(image)
        canvas.setBlendPreview(effect: nil, intensity: 0)
        canvas.setImage(session.currentImage)
        liquifyBrushView.setActive(false)
        setSecondaryHeight(0)
        selectTool(availableTools.first { $0 != .liquify })
    }

    func liquifyToolPanelDidCancel(_ panel: LiquifyToolPanel) {
        canvas.setBlendPreview(effect: nil, intensity: 0)
        liquifyBrushView.setActive(false)
        setSecondaryHeight(0)
        selectTool(availableTools.first { $0 != .liquify })
    }

    func liquifyToolPanel(
        _ panel: LiquifyToolPanel,
        didChangeMode mode: LiquifyMode,
        radiusRatio: CGFloat,
        strength: CGFloat
    ) {
        liquifyBrushView.mode = mode
        liquifyBrushView.brushRadiusRatio = radiusRatio
        liquifyBrushView.strength = strength
    }
}

extension ImageEditorViewController: LiquifyBrushViewDelegate {
    func liquifyBrushViewRequestImageFrame(_ view: LiquifyBrushView) -> CGRect {
        canvas.convert(canvas.imageFrame, to: view)
    }

    func liquifyBrushView(
        _ view: LiquifyBrushView,
        didStroke mode: LiquifyMode,
        at point: CGPoint,
        delta: CGPoint,
        radius: CGFloat,
        strength: CGFloat
    ) {
        let frame = canvas.convert(canvas.imageFrame, to: view)
        let aspect = frame.height > 0 ? frame.width / frame.height : 1
        liquifyPanel.applyStroke(
            mode: mode,
            at: point,
            delta: delta,
            radius: radius,
            strength: strength,
            aspectRatio: aspect
        )
    }

    func liquifyBrushViewDidEndStroke(_ view: LiquifyBrushView) {
        liquifyPanel.endStroke()
    }
}

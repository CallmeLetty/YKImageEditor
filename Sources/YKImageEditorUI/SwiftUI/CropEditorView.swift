import AVFoundation
import SwiftUI
import UIKit
import YKImageEditorCore

struct CropEditorView: View {
    @StateObject private var model: CropEditorViewModel
    private let onCancel: () -> Void
    private let onComplete: (UIImage) -> Void

    init(
        image: UIImage,
        onCancel: @escaping () -> Void,
        onComplete: @escaping (UIImage) -> Void
    ) {
        _model = StateObject(wrappedValue: CropEditorViewModel(image: image))
        self.onCancel = onCancel
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                cropCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                bottomTools
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Label("取消", systemImage: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(height: 36)
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                onComplete(model.makeCroppedImage())
            } label: {
                Label("完成", systemImage: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(uiColor: EditorTheme.accent))
                    .frame(height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private var cropCanvas: some View {
        GeometryReader { proxy in
            let imageFrame = AVMakeRect(
                aspectRatio: model.workingImage.size,
                insideRect: CGRect(origin: .zero, size: proxy.size)
            )
            ZStack {
                Image(uiImage: model.workingImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                CropOverlayRepresentable(
                    imageFrame: imageFrame,
                    ratio: model.selectedRatio,
                    resetID: model.resetID
                ) { cropRect, activeImageFrame in
                    model.updateCropRect(cropRect, imageFrame: activeImageFrame)
                }
            }
        }
    }

    private var bottomTools: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(model.ratioOptions) { option in
                    Button {
                        model.selectRatio(option)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: option.systemImageName)
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 22, height: 22)
                            Text(option.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(
                            model.selectedRatioID == option.id
                                ? Color(uiColor: EditorTheme.accent)
                                : .white
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                CropActionButton(title: "旋转", systemName: "rotate.right", action: model.rotate)
                CropActionButton(title: "左右翻转", systemName: "arrow.left.and.right") {
                    model.flip(horizontal: true, vertical: false)
                }
                CropActionButton(title: "上下翻转", systemName: "arrow.up.and.down") {
                    model.flip(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.black)
    }
}

@MainActor
private final class CropEditorViewModel: ObservableObject {
    @Published private(set) var workingImage: UIImage
    @Published private(set) var selectedRatioID = "free"
    @Published private(set) var resetID = 0

    private(set) var selectedRatio: CGFloat?
    private var cropRect = CGRect.zero
    private var imageFrame = CGRect.zero

    var ratioOptions: [CropRatioOption] {
        [
            CropRatioOption(id: "free", title: "自由", systemImageName: "crop", ratio: nil),
            CropRatioOption(id: "square", title: "1:1", systemImageName: "square", ratio: 1),
            CropRatioOption(id: "fourThree", title: "4:3", systemImageName: "rectangle", ratio: 4 / 3),
            CropRatioOption(id: "sixteenNine", title: "16:9", systemImageName: "rectangle", ratio: 16 / 9),
            CropRatioOption(
                id: "original",
                title: "原图",
                systemImageName: "photo",
                ratio: workingImage.size.width / max(workingImage.size.height, 1)
            )
        ]
    }

    init(image: UIImage) {
        workingImage = image
    }

    func selectRatio(_ option: CropRatioOption) {
        selectedRatioID = option.id
        selectedRatio = option.ratio
        resetID += 1
    }

    func rotate() {
        workingImage = ImageGeometry.rotate90(workingImage, quarterTurns: 1)
        if selectedRatioID == "original" {
            selectedRatio = workingImage.size.width / max(workingImage.size.height, 1)
        }
        resetID += 1
    }

    func flip(horizontal: Bool, vertical: Bool) {
        workingImage = ImageGeometry.flip(
            workingImage,
            horizontal: horizontal,
            vertical: vertical
        )
    }

    func updateCropRect(_ cropRect: CGRect, imageFrame: CGRect) {
        self.cropRect = cropRect
        self.imageFrame = imageFrame
    }

    func makeCroppedImage() -> UIImage {
        guard imageFrame.width > 0, imageFrame.height > 0, cropRect.width > 0, cropRect.height > 0 else {
            return workingImage
        }
        let normalizedRect = CGRect(
            x: (cropRect.minX - imageFrame.minX) / imageFrame.width,
            y: (cropRect.minY - imageFrame.minY) / imageFrame.height,
            width: cropRect.width / imageFrame.width,
            height: cropRect.height / imageFrame.height
        )
        return ImageGeometry.crop(workingImage, normalizedRect: normalizedRect)
    }
}

private struct CropRatioOption: Identifiable {
    let id: String
    let title: String
    let systemImageName: String
    let ratio: CGFloat?
}

private struct CropActionButton: View {
    let title: String
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 22, height: 22)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CropOverlayRepresentable: UIViewRepresentable {
    let imageFrame: CGRect
    let ratio: CGFloat?
    let resetID: Int
    let onCropRectChange: (CGRect, CGRect) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CropRectView {
        let view = CropRectView()
        view.onCropRectChange = { [weak coordinator = context.coordinator] cropRect in
            guard let coordinator else { return }
            DispatchQueue.main.async {
                coordinator.parent.onCropRectChange(cropRect, coordinator.parent.imageFrame)
            }
        }
        return view
    }

    func updateUIView(_ uiView: CropRectView, context: Context) {
        context.coordinator.parent = self
        let frameChanged = context.coordinator.lastImageFrame != imageFrame
        let resetChanged = context.coordinator.lastResetID != resetID
        context.coordinator.lastImageFrame = imageFrame
        context.coordinator.lastResetID = resetID
        uiView.imageFrame = imageFrame
        if frameChanged || resetChanged || uiView.cropRect == .zero {
            uiView.resetCropRect(ratio: ratio)
        }
    }

    final class Coordinator {
        var parent: CropOverlayRepresentable
        var lastImageFrame = CGRect.zero
        var lastResetID = -1

        init(parent: CropOverlayRepresentable) {
            self.parent = parent
        }
    }
}

/// 裁剪框精确触摸层，由 SwiftUI 裁剪页面桥接使用。
final class CropRectView: UIView {
    var imageFrame: CGRect = .zero
    private(set) var cropRect: CGRect = .zero
    var onCropRectChange: ((CGRect) -> Void)?

    private let dimLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let gridLayer = CAShapeLayer()
    private let cornerLayer = CAShapeLayer()
    private var activeCorner: Corner?
    private var panStart = CGPoint.zero
    private var startRect = CGRect.zero
    private var lockedRatio: CGFloat?

    private enum Corner {
        case move, topLeft, topRight, bottomLeft, bottomRight
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.68).cgColor
        borderLayer.strokeColor = EditorTheme.accent.cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 2
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.65).cgColor
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.lineWidth = 1
        cornerLayer.strokeColor = UIColor.white.cgColor
        cornerLayer.fillColor = UIColor.clear.cgColor
        cornerLayer.lineWidth = 5
        cornerLayer.lineCap = .round
        cornerLayer.lineJoin = .round
        layer.addSublayer(dimLayer)
        layer.addSublayer(gridLayer)
        layer.addSublayer(borderLayer)
        layer.addSublayer(cornerLayer)

        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func resetCropRect(ratio: CGFloat?) {
        lockedRatio = ratio
        guard imageFrame.width > 0, imageFrame.height > 0 else { return }
        if let ratio, ratio > 0 {
            var width = imageFrame.width
            var height = width / ratio
            if height > imageFrame.height {
                height = imageFrame.height
                width = height * ratio
            }
            cropRect = CGRect(
                x: imageFrame.midX - width / 2,
                y: imageFrame.midY - height / 2,
                width: width,
                height: height
            )
        } else {
            cropRect = imageFrame.insetBy(dx: imageFrame.width * 0.05, dy: imageFrame.height * 0.05)
        }
        updateLayers()
        onCropRectChange?(cropRect)
    }

    private func updateLayers() {
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(rect: cropRect))
        dimLayer.path = path.cgPath
        borderLayer.path = UIBezierPath(rect: cropRect).cgPath
        gridLayer.path = gridPath(in: cropRect).cgPath
        cornerLayer.path = cornerPath(in: cropRect).cgPath
    }

    private func gridPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width > 0, rect.height > 0 else { return path }
        for step in 1...2 {
            let x = rect.minX + rect.width * CGFloat(step) / 3
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * CGFloat(step) / 3
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }

    private func cornerPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width > 0, rect.height > 0 else { return path }
        let length = min(30, rect.width / 4, rect.height / 4)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        return path
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayers()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            activeCorner = hitTestCorner(point)
            panStart = point
            startRect = cropRect
        case .changed:
            guard let corner = activeCorner else { return }
            let dx = point.x - panStart.x
            let dy = point.y - panStart.y
            var rect = startRect
            switch corner {
            case .move:
                rect.origin.x += dx
                rect.origin.y += dy
            case .topLeft:
                rect.origin.x += dx
                rect.origin.y += dy
                rect.size.width -= dx
                rect.size.height -= dy
            case .topRight:
                rect.origin.y += dy
                rect.size.width += dx
                rect.size.height -= dy
            case .bottomLeft:
                rect.origin.x += dx
                rect.size.width -= dx
                rect.size.height += dy
            case .bottomRight:
                rect.size.width += dx
                rect.size.height += dy
            }
            cropRect = clamp(rect)
            updateLayers()
            onCropRectChange?(cropRect)
        default:
            activeCorner = nil
        }
    }

    private func hitTestCorner(_ point: CGPoint) -> Corner? {
        let inset: CGFloat = 28
        let topLeft = CGRect(x: cropRect.minX - inset / 2, y: cropRect.minY - inset / 2, width: inset, height: inset)
        let topRight = CGRect(x: cropRect.maxX - inset / 2, y: cropRect.minY - inset / 2, width: inset, height: inset)
        let bottomLeft = CGRect(x: cropRect.minX - inset / 2, y: cropRect.maxY - inset / 2, width: inset, height: inset)
        let bottomRight = CGRect(x: cropRect.maxX - inset / 2, y: cropRect.maxY - inset / 2, width: inset, height: inset)
        if topLeft.contains(point) { return .topLeft }
        if topRight.contains(point) { return .topRight }
        if bottomLeft.contains(point) { return .bottomLeft }
        if bottomRight.contains(point) { return .bottomRight }
        return cropRect.contains(point) ? .move : nil
    }

    private func clamp(_ rect: CGRect) -> CGRect {
        var result = rect
        result.size.width = max(result.width, 40)
        result.size.height = max(result.height, 40)
        if let ratio = lockedRatio, ratio > 0, activeCorner != .move {
            result.size.height = result.width / ratio
        }
        if result.minX < imageFrame.minX { result.origin.x = imageFrame.minX }
        if result.minY < imageFrame.minY { result.origin.y = imageFrame.minY }
        if result.maxX > imageFrame.maxX { result.origin.x = imageFrame.maxX - result.width }
        if result.maxY > imageFrame.maxY { result.origin.y = imageFrame.maxY - result.height }
        return result.intersection(imageFrame)
    }
}

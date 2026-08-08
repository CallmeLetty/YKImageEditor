import AVFoundation
import UIKit
import YKImageEditorCore

protocol CropToolViewControllerDelegate: AnyObject {
    func cropTool(_ controller: CropToolViewController, didFinish image: UIImage)
    func cropToolDidCancel(_ controller: CropToolViewController)
}

/// 裁剪子界面：自由裁剪、固定比例、旋转与翻转。
final class CropToolViewController: UIViewController {
    weak var delegate: CropToolViewControllerDelegate?

    private let sourceImage: UIImage
    private var workingImage: UIImage
    private let imageView = UIImageView()
    private let cropOverlay = CropRectView()
    private var selectedRatio: CGFloat? // nil = free

    init(image: UIImage) {
        self.sourceImage = image
        self.workingImage = image
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        imageView.contentMode = .scaleAspectFit
        imageView.image = workingImage
        imageView.isUserInteractionEnabled = false
        view.addSubview(imageView)
        view.addSubview(cropOverlay)

        let topBar = makeTopBar()
        let bottomBar = makeBottomBar()
        view.addSubview(topBar)
        view.addSubview(bottomBar)

        topBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cropOverlay.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            cropOverlay.topAnchor.constraint(equalTo: imageView.topAnchor),
            cropOverlay.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            cropOverlay.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            cropOverlay.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cropOverlay.imageFrame = imageFrameInImageView()
        if cropOverlay.cropRect == .zero {
            cropOverlay.resetCropRect(ratio: selectedRatio)
        }
    }

    private func imageFrameInImageView() -> CGRect {
        guard let image = imageView.image else { return .zero }
        return AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds)
    }

    private func makeTopBar() -> UIView {
        let bar = UIView()
        let cancel = makeBarButton(title: "取消", systemImageName: "xmark")
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let done = makeBarButton(title: "完成", systemImageName: "checkmark", tintColor: EditorTheme.accent)
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        bar.addSubview(cancel)
        bar.addSubview(done)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        done.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cancel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            cancel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            done.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            done.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])
        return bar
    }

    private func makeBottomBar() -> UIView {
        let bar = UIView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        let ratioStack = UIStackView()
        ratioStack.axis = .horizontal
        ratioStack.distribution = .fillEqually
        ratioStack.spacing = 8

        let ratios: [(String, CGFloat?)] = [
            ("自由", nil),
            ("1:1", 1),
            ("4:3", 4 / 3),
            ("16:9", 16 / 9),
            ("原图", sourceImage.size.width / max(sourceImage.size.height, 1))
        ]
        for (title, ratio) in ratios {
            let button = makeRatioButton(title: title, systemImageName: ratioIconName(for: title))
            button.tag = ratios.firstIndex(where: { $0.0 == title }) ?? 0
            button.addAction(UIAction { [weak self] _ in
                self?.selectedRatio = ratio
                self?.cropOverlay.resetCropRect(ratio: ratio)
            }, for: .touchUpInside)
            ratioStack.addArrangedSubview(button)
        }

        let actionStack = UIStackView()
        actionStack.axis = .horizontal
        actionStack.distribution = .fillEqually
        actionStack.spacing = 8
        let rotate = makeActionButton("旋转", systemImageName: "rotate.right") { [weak self] in self?.rotate() }
        let flipH = makeActionButton("左右翻转", systemImageName: "arrow.left.and.right") { [weak self] in self?.flip(horizontal: true, vertical: false) }
        let flipV = makeActionButton("上下翻转", systemImageName: "arrow.up.and.down") { [weak self] in self?.flip(horizontal: false, vertical: true) }
        [rotate, flipH, flipV].forEach { actionStack.addArrangedSubview($0) }

        stack.addArrangedSubview(ratioStack)
        stack.addArrangedSubview(actionStack)
        bar.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bar.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            ratioStack.heightAnchor.constraint(equalToConstant: 50),
            actionStack.heightAnchor.constraint(equalToConstant: 60)
        ])
        return bar
    }

    private func makeBarButton(
        title: String,
        systemImageName: String,
        tintColor: UIColor = .white
    ) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemImageName)
        configuration.imagePadding = 6
        configuration.baseForegroundColor = tintColor
        configuration.title = title
        button.configuration = configuration
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        return button
    }

    private func makeRatioButton(title: String, systemImageName: String) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: systemImageName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        )
        configuration.imagePlacement = .top
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        configuration.baseForegroundColor = .white
        configuration.titleAlignment = .center
        configuration.title = title
        button.configuration = configuration
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        return button
    }

    private func makeActionButton(
        _ title: String,
        systemImageName: String,
        action: @escaping () -> Void
    ) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(
            systemName: systemImageName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        )
        configuration.imagePlacement = .top
        configuration.imagePadding = 5
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4)
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = UIColor.white.withAlphaComponent(0.12)
        configuration.cornerStyle = .medium
        configuration.titleAlignment = .center
        configuration.title = title
        button.configuration = configuration
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func ratioIconName(for title: String) -> String {
        switch title {
        case "自由": return "crop"
        case "原图": return "photo"
        case "1:1": return "square"
        default: return "rectangle"
        }
    }

    private func rotate() {
        workingImage = ImageGeometry.rotate90(workingImage, quarterTurns: 1)
        imageView.image = workingImage
        cropOverlay.resetCropRect(ratio: selectedRatio)
        view.setNeedsLayout()
    }

    private func flip(horizontal: Bool, vertical: Bool) {
        workingImage = ImageGeometry.flip(workingImage, horizontal: horizontal, vertical: vertical)
        imageView.image = workingImage
    }

    @objc private func cancelTapped() {
        delegate?.cropToolDidCancel(self)
    }

    @objc private func doneTapped() {
        let imageFrame = imageFrameInImageView()
        guard imageFrame.width > 0, imageFrame.height > 0 else {
            delegate?.cropTool(self, didFinish: workingImage)
            return
        }
        let crop = cropOverlay.cropRect
        let normalized = CGRect(
            x: (crop.minX - imageFrame.minX) / imageFrame.width,
            y: (crop.minY - imageFrame.minY) / imageFrame.height,
            width: crop.width / imageFrame.width,
            height: crop.height / imageFrame.height
        )
        let result = ImageGeometry.crop(workingImage, normalizedRect: normalized)
        delegate?.cropTool(self, didFinish: result)
    }
}

/// 可拖拽裁剪框。
final class CropRectView: UIView {
    var imageFrame: CGRect = .zero
    private(set) var cropRect: CGRect = .zero
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

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
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
        default:
            activeCorner = nil
        }
    }

    private func hitTestCorner(_ point: CGPoint) -> Corner {
        let inset: CGFloat = 28
        let tl = CGRect(x: cropRect.minX - inset / 2, y: cropRect.minY - inset / 2, width: inset, height: inset)
        let tr = CGRect(x: cropRect.maxX - inset / 2, y: cropRect.minY - inset / 2, width: inset, height: inset)
        let bl = CGRect(x: cropRect.minX - inset / 2, y: cropRect.maxY - inset / 2, width: inset, height: inset)
        let br = CGRect(x: cropRect.maxX - inset / 2, y: cropRect.maxY - inset / 2, width: inset, height: inset)
        if tl.contains(point) { return .topLeft }
        if tr.contains(point) { return .topRight }
        if bl.contains(point) { return .bottomLeft }
        if br.contains(point) { return .bottomRight }
        if cropRect.contains(point) { return .move }
        return .move
    }

    private func clamp(_ rect: CGRect) -> CGRect {
        var r = rect
        if r.width < 40 { r.size.width = 40 }
        if r.height < 40 { r.size.height = 40 }
        if let ratio = lockedRatio, ratio > 0, activeCorner != .move {
            r.size.height = r.width / ratio
        }
        if r.minX < imageFrame.minX {
            r.origin.x = imageFrame.minX
        }
        if r.minY < imageFrame.minY {
            r.origin.y = imageFrame.minY
        }
        if r.maxX > imageFrame.maxX {
            r.origin.x = imageFrame.maxX - r.width
        }
        if r.maxY > imageFrame.maxY {
            r.origin.y = imageFrame.maxY - r.height
        }
        r = r.intersection(imageFrame)
        return r
    }
}

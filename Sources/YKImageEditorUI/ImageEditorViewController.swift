import UIKit
import YKImageEditorCore

/// 微信风格图片编辑会话控制器。
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
    private let bottomBar = UIView()
    private let toolStack = UIStackView()
    private let colorStack = UIStackView()
    private var selectedTool: EditorTool?
    private var availableTools: [EditorTool] = []

    private let doodleColors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .white, .black
    ]

    /// - Parameters:
    ///   - image: 待编辑图片。
    ///   - config: 功能与导出配置。
    ///   - stickerProvider: 贴纸素材提供者；为 `nil` 时隐藏贴纸。
    ///   - completion: 结束回调，主线程触发。
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
        view.backgroundColor = .black
        configureTools()
        buildLayout()
        canvas.setImage(session.currentImage)
        selectTool(availableTools.first)
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
        view.addSubview(topBar)
        view.addSubview(bottomBar)

        canvas.translatesAutoresizingMaskIntoConstraints = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        buildTopBar()
        buildBottomBar()

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 110),

            canvas.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: bottomBar.topAnchor)
        ])
    }

    private func buildTopBar() {
        let cancel = UIButton(type: .system)
        cancel.setTitle("取消", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let undo = UIButton(type: .system)
        undo.setTitle("撤销", for: .normal)
        undo.setTitleColor(.white, for: .normal)
        undo.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)

        let redo = UIButton(type: .system)
        redo.setTitle("重做", for: .normal)
        redo.setTitleColor(.white, for: .normal)
        redo.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)

        let done = UIButton(type: .system)
        done.setTitle("完成", for: .normal)
        done.setTitleColor(.systemGreen, for: .normal)
        done.titleLabel?.font = .boldSystemFont(ofSize: 17)
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        [cancel, undo, redo, done].forEach {
            topBar.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            cancel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            cancel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            undo.leadingAnchor.constraint(equalTo: cancel.trailingAnchor, constant: 16),
            undo.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            redo.leadingAnchor.constraint(equalTo: undo.trailingAnchor, constant: 12),
            redo.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            done.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            done.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])
    }

    private func buildBottomBar() {
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.85)

        toolStack.axis = .horizontal
        toolStack.distribution = .fillEqually
        toolStack.alignment = .center

        for tool in availableTools {
            let button = UIButton(type: .system)
            button.setTitle(tool.title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14)
            button.tag = tool.rawValue
            button.addTarget(self, action: #selector(toolTapped(_:)), for: .touchUpInside)
            toolStack.addArrangedSubview(button)
        }

        colorStack.axis = .horizontal
        colorStack.spacing = 10
        colorStack.alignment = .center
        colorStack.distribution = .equalSpacing
        for (index, color) in doodleColors.enumerated() {
            let button = UIButton(type: .custom)
            button.backgroundColor = color
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.cgColor
            button.tag = index
            button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 24),
                button.heightAnchor.constraint(equalToConstant: 24)
            ])
            colorStack.addArrangedSubview(button)
        }

        let applyButton = UIButton(type: .system)
        applyButton.setTitle("应用当前图层", for: .normal)
        applyButton.setTitleColor(.systemGreen, for: .normal)
        applyButton.addTarget(self, action: #selector(applyOverlaysTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [colorStack, toolStack, applyButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        bottomBar.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])
    }

    private func selectTool(_ tool: EditorTool?) {
        selectedTool = tool
        canvas.doodleView.isHidden = tool != .doodle
        canvas.mosaicMaskView.isHidden = tool != .mosaic
        colorStack.isHidden = !(tool == .doodle || tool == .text)
        canvas.doodleView.isUserInteractionEnabled = tool == .doodle
        canvas.mosaicMaskView.isUserInteractionEnabled = tool == .mosaic

        for case let button as UIButton in toolStack.arrangedSubviews {
            let isSelected = button.tag == tool?.rawValue
            button.setTitleColor(isSelected ? .systemGreen : .white, for: .normal)
        }

        if tool == .crop {
            presentCrop()
        } else if tool == .text {
            promptText()
        } else if tool == .sticker {
            presentStickers()
        }
    }

    @objc private func toolTapped(_ sender: UIButton) {
        guard let tool = EditorTool(rawValue: sender.tag) else { return }
        // 切换工具前先把涂鸦/马赛克提交进会话，避免丢失。
        if selectedTool == .doodle || selectedTool == .mosaic {
            applyTransientDrawingIfNeeded()
        }
        selectTool(tool)
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
        // Temporarily hide drawing layers so they aren't double-applied.
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
            pop.sourceView = bottomBar
            pop.sourceRect = bottomBar.bounds
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
        applyTransientDrawingIfNeeded()
        if let image = session.undo() {
            canvas.clearTransientOverlays()
            canvas.setImage(image)
        }
    }

    @objc private func redoTapped() {
        if let image = session.redo() {
            canvas.clearTransientOverlays()
            canvas.setImage(image)
        }
    }

    @objc private func cancelTapped() {
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

extension ImageEditorViewController: CropToolViewControllerDelegate {
    func cropTool(_ controller: CropToolViewController, didFinish image: UIImage) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.session.commit(image)
            self.canvas.setImage(self.session.currentImage)
            self.selectTool(self.availableTools.first { $0 != .crop })
        }
    }

    func cropToolDidCancel(_ controller: CropToolViewController) {
        controller.dismiss(animated: true) { [weak self] in
            self?.selectTool(self?.availableTools.first { $0 != .crop })
        }
    }
}

import SwiftUI
import UIKit
import YKImageEditorCore

/// 图片编辑器的 UIKit 兼容入口，实际界面由 SwiftUI 构建。
///
/// 通过 ``UIViewController/yk_presentImageEditor(image:config:stickerProvider:animated:completion:)``
/// 或直接初始化后由宿主 `present` / `push`。
///
/// `completion` **始终在主线程**回调。
public final class ImageEditorViewController: UIViewController {
    private let completion: (ImageEditorResult) -> Void
    private let model: ImageEditorViewModel
    private var host: UIHostingController<ImageEditorContentView>?

    public init(
        image: UIImage,
        config: EditorConfig = .all,
        stickerProvider: StickerProviding? = nil,
        completion: @escaping (ImageEditorResult) -> Void
    ) {
        self.completion = completion
        model = ImageEditorViewModel(
            image: image,
            config: config,
            stickerProvider: stickerProvider
        )
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        model.onFinish = { [weak self] result in
            self?.finish(result)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let host = UIHostingController(rootView: ImageEditorContentView(model: model))
        self.host = host
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
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
            } else if let navigationController = self.navigationController,
                      navigationController.topViewController === self {
                navigationController.popViewController(animated: true)
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

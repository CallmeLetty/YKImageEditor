import UIKit
import YKImageEditorCore

public extension UIViewController {
    /// 以全屏 modal 方式打开图片编辑器。
    ///
    /// completion **始终在主线程**回调。
    ///
    /// - Parameters:
    ///   - image: 待编辑图片。
    ///   - config: 功能与导出配置，默认全部功能。
    ///   - stickerProvider: 贴纸素材；为 `nil` 时隐藏贴纸入口。
    ///   - animated: 是否动画 present。
    ///   - completion: 结束回调（完成或取消）。
    func yk_presentImageEditor(
        image: UIImage,
        config: EditorConfig = .all,
        stickerProvider: StickerProviding? = nil,
        animated: Bool = true,
        completion: @escaping (ImageEditorResult) -> Void
    ) {
        let editor = ImageEditorViewController(
            image: image,
            config: config,
            stickerProvider: stickerProvider,
            completion: completion
        )
        editor.modalPresentationStyle = .fullScreen
        present(editor, animated: animated)
    }
}

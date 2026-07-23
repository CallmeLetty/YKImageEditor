import UIKit

/// 贴纸素材提供者。
///
/// 未设置时，即使 ``EditorFeature/sticker`` 已启用，工具栏也会隐藏贴纸入口。
public protocol StickerProviding: AnyObject {
    /// 返回可供用户选择的贴纸图片列表。
    func stickersForEditor() -> [UIImage]
}

/// 闭包形式的贴纸 Provider，便于调用方快速注入。
public final class ClosureStickerProvider: StickerProviding {
    private let provider: () -> [UIImage]

    /// - Parameter provider: 返回贴纸列表的闭包。
    public init(_ provider: @escaping () -> [UIImage]) {
        self.provider = provider
    }

    public func stickersForEditor() -> [UIImage] {
        provider()
    }
}

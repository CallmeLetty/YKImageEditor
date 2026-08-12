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

enum StickerImageRendering {
    private static let minimumRasterizedTemplateSide: CGFloat = 160

    static func resolvedImage(_ image: UIImage) -> UIImage {
        if image.renderingMode == .alwaysOriginal {
            let minimumSide = image.isSymbolImage ? minimumRasterizedTemplateSide : nil
            return rasterizedOriginalImage(image, minimumSide: minimumSide)
        }

        if image.isSymbolImage || image.renderingMode == .alwaysTemplate {
            let tintedImage = image.withTintColor(EditorTheme.accent, renderingMode: .alwaysOriginal)
            return rasterizedOriginalImage(tintedImage, minimumSide: minimumRasterizedTemplateSide)
        }

        return image.withRenderingMode(.alwaysOriginal)
    }

    /// 将符号图或模板图固定成原色位图，避免深色环境下再次继承外部 tint。
    private static func rasterizedOriginalImage(_ image: UIImage, minimumSide: CGFloat? = nil) -> UIImage {
        var size = image.size
        if let minimumSide, max(size.width, size.height) > 0 {
            let scale = minimumSide / max(size.width, size.height)
            if scale > 1 {
                size = CGSize(width: size.width * scale, height: size.height * scale)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = max(image.scale, UIScreen.main.scale)
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
    }
}

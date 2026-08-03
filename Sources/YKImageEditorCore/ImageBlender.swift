import UIKit

/// 将上层颜色/图片按混合模式合成到照片上。
public enum ImageBlender {
    /// 用纯色层混合。
    ///
    /// - Parameters:
    ///   - base: 底图。
    ///   - color: 上层颜色。
    ///   - mode: 混合模式。
    ///   - opacity: 效果强度，`0...1`。`0` 为原图，`1` 为完整混合结果。
    public static func blend(
        base: UIImage,
        color: UIColor,
        mode: ImageBlendMode,
        opacity: CGFloat = 1
    ) -> UIImage {
        let overlay = BlendOverlayFactory.solid(
            color: color,
            size: base.size,
            scale: base.scale
        )
        return blend(base: base, overlay: overlay, mode: mode, opacity: opacity)
    }

    /// 用图片层混合。
    ///
    /// - Parameters:
    ///   - base: 底图。
    ///   - overlay: 上层图（会拉伸至底图尺寸）。
    ///   - mode: 混合模式。
    ///   - opacity: 效果强度，`0...1`。先做完整混合，再与原图按强度插值。
    public static func blend(
        base: UIImage,
        overlay: UIImage,
        mode: ImageBlendMode,
        opacity: CGFloat = 1
    ) -> UIImage {
        let intensity = min(max(opacity, 0), 1)
        guard intensity > 0 else { return base }

        let fullyBlended = blendFully(base: base, overlay: overlay, mode: mode)
        if intensity >= 0.999 { return fullyBlended }
        return mix(base: base, effect: fullyBlended, intensity: intensity)
    }

    /// 仅生成强度 100% 的混合结果（供 UI 预览层用透明度模拟强度）。
    public static func blendFully(
        base: UIImage,
        overlay: UIImage,
        mode: ImageBlendMode
    ) -> UIImage {
        let size = base.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            base.draw(in: rect)
            // 必须使用带 blendMode 的 API；先 setBlendMode 再 draw(in:) 会被覆盖成普通绘制。
            overlay.draw(in: rect, blendMode: mode.cgBlendMode, alpha: 1)
        }
    }

    /// 应用修图预设。
    public static func blend(
        base: UIImage,
        preset: BlendPreset,
        intensity: CGFloat = 0.75
    ) -> UIImage {
        let overlay = preset.makeOverlayImage(size: base.size, scale: base.scale)
        return blend(base: base, overlay: overlay, mode: preset.mode, opacity: intensity)
    }

    /// 原图与效果图按强度插值（GPU/CoreGraphics 路径，避免逐像素）。
    private static func mix(base: UIImage, effect: UIImage, intensity: CGFloat) -> UIImage {
        let size = base.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            base.draw(in: rect)
            effect.draw(in: rect, blendMode: .normal, alpha: intensity)
        }
    }
}

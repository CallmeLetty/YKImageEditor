import UIKit

/// 面向修图场景的混合预设。
///
/// 灵感来自常见图层混合实践：暖色加深、柔光渐变、滤色光效、色相偏移等。
public enum BlendPreset: String, CaseIterable, Sendable, Hashable {
    /// 暖色颜色加深：提升对比并染暖。
    case warmColorBurn
    /// 冷暖柔光渐变：温和改色与明暗。
    case softLightGradient
    /// 叠加光感渐变：保留阴影高光结构的同时染色。
    case overlayLighting
    /// 强光风格化渐变。
    case hardLightGradient
    /// 正片叠底纸感：轻微压暗与纹理感。
    case paperMultiply
    /// 滤色暖光：模拟光斑/暖光（亮色叠在暗底上的效果）。
    case screenGlow
    /// 线性减淡强光。
    case plusLighterGlow
    /// 色相偏橙。
    case hueOrange
    /// 颜色着色（青绿）。
    case colorTeal
    /// 排除模式撞色渐变。
    case exclusionPop
    /// 饱和度提升（粉调层）。
    case saturationBoost

    /// 中文展示名。
    public var displayName: String {
        switch self {
        case .warmColorBurn: return "暖色加深"
        case .softLightGradient: return "柔光渐变"
        case .overlayLighting: return "叠加光感"
        case .hardLightGradient: return "强光渐变"
        case .paperMultiply: return "纸感压暗"
        case .screenGlow: return "滤色暖光"
        case .plusLighterGlow: return "加光"
        case .hueOrange: return "橙色散相"
        case .colorTeal: return "青绿着色"
        case .exclusionPop: return "排除撞色"
        case .saturationBoost: return "提饱和"
        }
    }

    /// 该预设使用的混合模式。
    public var mode: ImageBlendMode {
        switch self {
        case .warmColorBurn: return .colorBurn
        case .softLightGradient: return .softLight
        case .overlayLighting: return .overlay
        case .hardLightGradient: return .hardLight
        case .paperMultiply: return .multiply
        case .screenGlow: return .screen
        case .plusLighterGlow: return .plusLighter
        case .hueOrange: return .hue
        case .colorTeal: return .color
        case .exclusionPop: return .exclusion
        case .saturationBoost: return .saturation
        }
    }

    /// 生成与目标尺寸匹配的上层叠图。
    public func makeOverlayImage(size: CGSize, scale: CGFloat) -> UIImage {
        switch self {
        case .warmColorBurn:
            return BlendOverlayFactory.solid(
                color: UIColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1),
                size: size,
                scale: scale
            )
        case .softLightGradient, .overlayLighting, .hardLightGradient:
            return BlendOverlayFactory.linearGradient(
                colors: [
                    UIColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 1),
                    UIColor(red: 0.25, green: 0.45, blue: 0.95, alpha: 1)
                ],
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 1, y: 1),
                size: size,
                scale: scale
            )
        case .paperMultiply:
            return BlendOverlayFactory.paperTexture(size: size, scale: scale)
        case .screenGlow, .plusLighterGlow:
            return BlendOverlayFactory.radialGlow(
                color: UIColor(red: 1.0, green: 0.85, blue: 0.45, alpha: 1),
                size: size,
                scale: scale
            )
        case .hueOrange:
            return BlendOverlayFactory.solid(color: .orange, size: size, scale: scale)
        case .colorTeal:
            return BlendOverlayFactory.solid(color: .systemTeal, size: size, scale: scale)
        case .exclusionPop:
            return BlendOverlayFactory.linearGradient(
                colors: [.systemPurple, .systemOrange, .systemCyan],
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 1, y: 1),
                size: size,
                scale: scale
            )
        case .saturationBoost:
            return BlendOverlayFactory.solid(
                color: UIColor(hue: 0, saturation: 0.35, brightness: 0.85, alpha: 1),
                size: size,
                scale: scale
            )
        }
    }
}

enum BlendOverlayFactory {
    static func solid(color: UIColor, size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func linearGradient(
        colors: [UIColor],
        start: CGPoint,
        end: CGPoint,
        size: CGSize,
        scale: CGFloat
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let cgColors = colors.map(\.cgColor) as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors,
                locations: nil
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: start.x * size.width, y: start.y * size.height),
                end: CGPoint(x: end.x * size.width, y: end.y * size.height),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
    }

    static func radialGlow(color: UIColor, size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let center = CGPoint(x: size.width * 0.7, y: size.height * 0.3)
            let radius = max(size.width, size.height) * 0.55
            let colors = [
                color.cgColor,
                color.withAlphaComponent(0.35).cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.45, 1] as [CGFloat]
            ) else { return }
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    static func paperTexture(size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor(white: 0.92, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            // 少量固定噪点即可；避免按像素面积循环导致大图卡顿。
            let dotCount = min(1200, max(80, Int(max(size.width, size.height))))
            for i in 0..<dotCount {
                // 确定性坐标，避免 random 开销与闪烁
                let x = CGFloat((i * 67) % max(Int(size.width), 1))
                let y = CGFloat((i * 97) % max(Int(size.height), 1))
                let gray = 0.75 + CGFloat(i % 20) / 100
                UIColor(white: gray, alpha: 0.35).setFill()
                context.fill(CGRect(x: x, y: y, width: 1.5, height: 1.5))
            }
        }
    }
}

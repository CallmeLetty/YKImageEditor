import CoreGraphics

/// 图片混合模式。
///
/// 语义对齐常见图层混合（SwiftUI `BlendMode` / Core Graphics `CGBlendMode`）：
/// 将上层颜色/图层与下层照片合成，用于叠色、光效、对比度与色相处理。
public enum ImageBlendMode: String, CaseIterable, Sendable, Hashable {
    /// 标准 Alpha 合成（默认）。
    case normal
    /// 正片叠底：乘色变暗；白不变，黑变黑。适合纸张纹理、阴影叠层。
    case multiply
    /// 变暗：逐通道取较小值。
    case darken
    /// 颜色加深：强化对比并推向黑色。适合暖色氛围叠色。
    case colorBurn
    /// 线性加深（plusDarker）：比正片叠底更快压暗。
    case plusDarker
    /// 滤色：乘色变亮的反操作；黑不变，白变白。适合黑底光效/光斑。
    case screen
    /// 变亮：逐通道取较大值。
    case lighten
    /// 颜色减淡：更强的提亮，易推到白色。
    case colorDodge
    /// 线性减淡（plusLighter）：加法叠加，适合发光。
    case plusLighter
    /// 叠加：暗部乘、亮部滤色，保留原图明暗结构。
    case overlay
    /// 柔光：比叠加更柔和的明暗调节。
    case softLight
    /// 强光：以上层决定乘/滤色，风格更硬。
    case hardLight
    /// 差值：相似变黑、差异高亮。适合对比两图或做反相风格。
    case difference
    /// 排除：类似差值但中灰对比更低，适合大胆调色。
    case exclusion
    /// 色相：取上层色相，保留下层饱和度与亮度。
    case hue
    /// 饱和度：取上层饱和度，保留下层色相与亮度。
    case saturation
    /// 颜色：取上层色相+饱和度，保留下层亮度（灰度上色常用）。
    case color
    /// 明度：取上层亮度，保留下层色相+饱和度。
    case luminosity

    /// 对应的 Core Graphics 混合模式。
    public var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .darken: return .darken
        case .colorBurn: return .colorBurn
        case .plusDarker: return .plusDarker
        case .screen: return .screen
        case .lighten: return .lighten
        case .colorDodge: return .colorDodge
        case .plusLighter: return .plusLighter
        case .overlay: return .overlay
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        }
    }

    /// 中文展示名。
    public var displayName: String {
        switch self {
        case .normal: return "正常"
        case .multiply: return "正片叠底"
        case .darken: return "变暗"
        case .colorBurn: return "颜色加深"
        case .plusDarker: return "线性加深"
        case .screen: return "滤色"
        case .lighten: return "变亮"
        case .colorDodge: return "颜色减淡"
        case .plusLighter: return "线性减淡"
        case .overlay: return "叠加"
        case .softLight: return "柔光"
        case .hardLight: return "强光"
        case .difference: return "差值"
        case .exclusion: return "排除"
        case .hue: return "色相"
        case .saturation: return "饱和度"
        case .color: return "颜色"
        case .luminosity: return "明度"
        }
    }
}

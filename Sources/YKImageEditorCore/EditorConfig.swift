import Foundation

/// 编辑器会话配置。
///
/// 使用工厂方法选择功能集合：
/// - ``all``：开启全部功能
/// - ``including(_:)``：只开启指定功能
/// - ``excluding(_:)``：开启全部后去掉指定功能
public struct EditorConfig: Sendable, Equatable {
    /// 当前启用的功能集合。
    public var features: EditorFeature

    /// 导出选项（尺寸上限、编码格式等）。
    public var exportOptions: ExportOptions

    /// - Parameters:
    ///   - features: 启用的功能。
    ///   - exportOptions: 导出选项，默认 ``ExportOptions/default``。
    public init(
        features: EditorFeature = .all,
        exportOptions: ExportOptions = .default
    ) {
        self.features = features
        self.exportOptions = exportOptions
    }

    /// 开启全部功能。
    public static var all: EditorConfig {
        EditorConfig(features: .all)
    }

    /// 只开启指定功能。
    ///
    /// 示例：`EditorConfig.including([.crop, .text])`
    public static func including(_ features: EditorFeature) -> EditorConfig {
        EditorConfig(features: features)
    }

    /// 在全部功能基础上排除指定项。
    ///
    /// 示例：`EditorConfig.excluding([.mosaic, .sticker])`
    public static func excluding(_ features: EditorFeature) -> EditorConfig {
        EditorConfig(features: EditorFeature.all.subtracting(features))
    }

    /// 是否启用某一功能。
    public func isEnabled(_ feature: EditorFeature) -> Bool {
        features.contains(feature)
    }
}

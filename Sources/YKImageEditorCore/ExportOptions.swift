import CoreGraphics
import Foundation

/// 导出时的尺寸与编码选项。
public struct ExportOptions: Sendable, Equatable {
    /// 工作图与导出图的最长边上限（像素）。超过则等比缩小。
    ///
    /// 默认 `4096`。设为 `0` 或负数表示不限制（不推荐，大图易 OOM）。
    public var maxDimension: CGFloat

    /// JPEG 压缩质量，范围 `0...1`。仅在 ``preferJPEG`` 为 `true` 时生效。
    public var jpegQuality: CGFloat

    /// 为 `true` 时优先导出 JPEG（不保留透明）；为 `false` 时导出 PNG（保留透明）。
    public var preferJPEG: Bool

    /// - Parameters:
    ///   - maxDimension: 最长边上限，默认 4096。
    ///   - jpegQuality: JPEG 质量，默认 0.9。
    ///   - preferJPEG: 是否优先 JPEG，默认 `true`。
    public init(
        maxDimension: CGFloat = 4096,
        jpegQuality: CGFloat = 0.9,
        preferJPEG: Bool = true
    ) {
        self.maxDimension = maxDimension
        self.jpegQuality = min(max(jpegQuality, 0), 1)
        self.preferJPEG = preferJPEG
    }

    /// 常用默认：最长边 4096、JPEG 0.9。
    public static let `default` = ExportOptions()
}

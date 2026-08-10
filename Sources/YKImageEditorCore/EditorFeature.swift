import Foundation

/// 编辑器可开关的功能集合。
///
/// 通过 ``EditorConfig/including(_:)`` 或 ``EditorConfig/excluding(_:)`` 配置；
/// 默认 ``all`` 表示开启全部功能。
public struct EditorFeature: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// 裁剪：自由裁剪、固定比例，以及旋转 / 翻转。
    public static let crop = EditorFeature(rawValue: 1 << 0)

    /// 涂鸦：若干颜色的画笔涂抹。
    public static let doodle = EditorFeature(rawValue: 1 << 1)

    /// 文字：添加、拖动与改色。
    public static let text = EditorFeature(rawValue: 1 << 2)

    /// 马赛克：方格马赛克与涂抹马赛克。
    public static let mosaic = EditorFeature(rawValue: 1 << 3)

    /// 贴纸：缩放、旋转、拖动。素材由调用方通过贴纸 Provider 注入；未注入时 UI 自动隐藏入口。
    public static let sticker = EditorFeature(rawValue: 1 << 4)

    /// Blend 滤镜：以色块/渐变/光效图层按混合模式叠色调色。
    public static let blend = EditorFeature(rawValue: 1 << 5)

    /// 液化：推移塑形（推脸、微调轮廓）。
    public static let liquify = EditorFeature(rawValue: 1 << 6)

    /// Tone 滤镜：曝光、亮度、对比度、饱和度、色温、高光和阴影调整。
    public static let tone = EditorFeature(rawValue: 1 << 7)

    /// 全部功能（默认）。
    public static let all: EditorFeature = [
        .crop, .doodle, .text, .mosaic, .sticker, .blend, .liquify, .tone
    ]
}

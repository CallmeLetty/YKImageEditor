import Foundation

/// Tone 滤镜的可调参数。除曝光外，所有参数的建议范围都是 `-1...1`，`0` 表示不调整。
public struct ToneFilterParameters: Sendable, Equatable {
    /// 曝光补偿，单位为 EV，建议范围 `-2...2`。
    public var exposure: Float
    public var brightness: Float
    public var contrast: Float
    public var saturation: Float
    public var temperature: Float
    public var highlights: Float
    public var shadows: Float

    public init(
        exposure: Float = 0,
        brightness: Float = 0,
        contrast: Float = 0,
        saturation: Float = 0,
        temperature: Float = 0,
        highlights: Float = 0,
        shadows: Float = 0
    ) {
        self.exposure = exposure
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        self.highlights = highlights
        self.shadows = shadows
    }

    public var isIdentity: Bool {
        exposure == 0
            && brightness == 0
            && contrast == 0
            && saturation == 0
            && temperature == 0
            && highlights == 0
            && shadows == 0
    }

    public static let identity = ToneFilterParameters()
}

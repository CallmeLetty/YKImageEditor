import YKImageEditorCore

enum EditorTool: Int, CaseIterable, Identifiable {
    case crop
    case liquify
    case blend
    case tone
    case sticker
    case text
    case doodle
    case mosaic

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .crop: return "裁剪"
        case .liquify: return "液化"
        case .blend: return "Blend滤镜"
        case .tone: return "Tone滤镜"
        case .sticker: return "贴纸"
        case .text: return "文字"
        case .doodle: return "涂鸦"
        case .mosaic: return "马赛克"
        }
    }

    var systemImageName: String {
        switch self {
        case .crop: return "crop"
        case .liquify: return "hand.draw"
        case .blend: return "camera.filters"
        case .tone: return "slider.horizontal.3"
        case .sticker: return "face.smiling"
        case .text: return "textformat"
        case .doodle: return "pencil.tip"
        case .mosaic: return "square.grid.3x3"
        }
    }

    var feature: EditorFeature {
        switch self {
        case .crop: return .crop
        case .liquify: return .liquify
        case .blend: return .blend
        case .tone: return .tone
        case .sticker: return .sticker
        case .text: return .text
        case .doodle: return .doodle
        case .mosaic: return .mosaic
        }
    }
}

enum ToneParameter: String, CaseIterable, Identifiable {
    case exposure
    case brightness
    case contrast
    case saturation
    case temperature
    case highlights
    case shadows

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exposure: return "曝光"
        case .brightness: return "亮度"
        case .contrast: return "对比"
        case .saturation: return "饱和"
        case .temperature: return "色温"
        case .highlights: return "高光"
        case .shadows: return "阴影"
        }
    }

    var systemImageName: String {
        switch self {
        case .exposure: return "plusminus.circle"
        case .brightness: return "sun.max"
        case .contrast: return "circle.lefthalf.filled"
        case .saturation: return "drop.fill"
        case .temperature: return "thermometer.medium"
        case .highlights: return "sun.max.fill"
        case .shadows: return "moon.fill"
        }
    }

    var range: ClosedRange<Double> {
        self == .exposure ? -2...2 : -1...1
    }

    var step: Double { self == .exposure ? 0.05 : 0.01 }
}

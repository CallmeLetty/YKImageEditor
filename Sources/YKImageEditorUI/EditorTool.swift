import YKImageEditorCore

enum EditorTool: Int, CaseIterable, Identifiable {
    case crop
    case liquify
    case blend
    case sticker
    case text
    case doodle
    case mosaic

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .crop: return "裁剪"
        case .liquify: return "液化"
        case .blend: return "滤镜"
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
        case .sticker: return .sticker
        case .text: return .text
        case .doodle: return .doodle
        case .mosaic: return .mosaic
        }
    }
}

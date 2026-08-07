import YKImageEditorCore

enum EditorTool: Int, CaseIterable {
    case doodle
    case text
    case mosaic
    case sticker
    case blend
    case liquify
    case crop

    var title: String {
        switch self {
        case .doodle: return "涂鸦"
        case .text: return "文字"
        case .mosaic: return "马赛克"
        case .sticker: return "贴纸"
        case .blend: return "混合"
        case .liquify: return "液化"
        case .crop: return "裁剪"
        }
    }

    var feature: EditorFeature {
        switch self {
        case .doodle: return .doodle
        case .text: return .text
        case .mosaic: return .mosaic
        case .sticker: return .sticker
        case .blend: return .blend
        case .liquify: return .liquify
        case .crop: return .crop
        }
    }
}

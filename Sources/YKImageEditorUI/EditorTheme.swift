import UIKit

/// 编辑器视觉主题（对齐醒图式深色 + 柠檬绿强调）。
enum EditorTheme {
    static let background = UIColor.black
    static let panel = UIColor.black
    static let panelElevated = UIColor(white: 0.08, alpha: 1)
    static let accent = UIColor(red: 0.72, green: 1.0, blue: 0.08, alpha: 1) // ≈ #B8FF14
    static let accentText = UIColor.black
    static let primaryText = UIColor.white
    static let secondaryText = UIColor(white: 0.62, alpha: 1)
    static let chip = UIColor(white: 1, alpha: 0.1)
    static let chipSelected = UIColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 0.85)

    static let categoryHeight: CGFloat = 52
    static let topBarHeight: CGFloat = 48
}

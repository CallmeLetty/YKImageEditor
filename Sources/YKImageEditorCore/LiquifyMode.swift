import Foundation

/// 液化笔刷模式。
public enum LiquifyMode: String, CaseIterable, Sendable, Hashable {
    /// 推移：沿手指滑动方向推动像素（推脸、微调轮廓）。
    case push

    /// 中文展示名。
    public var displayName: String {
        switch self {
        case .push: return "推移"
        }
    }
}

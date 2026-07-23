import UIKit

/// 编辑会话结束时的结果。
public enum ImageEditorResult {
    /// 用户确认导出。
    case finished(UIImage)
    /// 用户取消（含放弃编辑）。
    case cancelled
}

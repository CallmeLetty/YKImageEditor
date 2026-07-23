import UIKit

/// 单次编辑会话的状态机：持有工作图、脏标记与撤销栈。
///
/// UI 层在用户操作后调用 ``commit(_:)``；导出时调用 ``makeExportImage(options:)``。
public final class EditorSession {
    /// 进入会话时的原始图（已方向规范化，并按导出上限降采样）。
    public let originalImage: UIImage

    /// 当前工作图。
    public private(set) var currentImage: UIImage

    /// 是否存在未重置的编辑。
    public var isDirty: Bool {
        !undoStack.isEmpty || currentImage !== originalImage
    }

    /// 是否可撤销。
    public var canUndo: Bool { !undoStack.isEmpty }

    /// 是否可重做。
    public var canRedo: Bool { !redoStack.isEmpty }

    private var undoStack: [UIImage] = []
    private var redoStack: [UIImage] = []

    /// - Parameters:
    ///   - image: 输入原图。
    ///   - maxDimension: 工作图最长边上限，通常取自 ``ExportOptions/maxDimension``。
    public init(image: UIImage, maxDimension: CGFloat) {
        let normalized = ImageGeometry.normalizedOrientation(image)
        let working = ImageGeometry.downsample(normalized, maxDimension: maxDimension)
        self.originalImage = working
        self.currentImage = working
    }

    /// 提交一版新的工作图，压入撤销栈并清空重做栈。
    public func commit(_ image: UIImage) {
        undoStack.append(currentImage)
        redoStack.removeAll()
        currentImage = image
    }

    /// 撤销到上一版工作图。
    @discardableResult
    public func undo() -> UIImage? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(currentImage)
        currentImage = previous
        return currentImage
    }

    /// 重做。
    @discardableResult
    public func redo() -> UIImage? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(currentImage)
        currentImage = next
        return currentImage
    }

    /// 丢弃全部编辑，回到会话初始工作图。
    public func reset() {
        guard isDirty else { return }
        undoStack.append(currentImage)
        redoStack.removeAll()
        currentImage = originalImage
    }

    /// 按选项导出当前工作图。
    public func makeExportImage(options: ExportOptions) -> UIImage {
        ImageExporter.export(currentImage, options: options)
    }
}

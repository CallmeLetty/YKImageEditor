import UIKit

/// 涂抹马赛克遮罩：不透明笔画表示需要打码的区域。
final class MosaicMaskView: UIView {
    var brushWidth: CGFloat = 28

    private var paths: [UIBezierPath] = []
    private var currentPath: UIBezierPath?

    var hasContent: Bool { !paths.isEmpty || currentPath != nil }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clear() {
        paths.removeAll()
        currentPath = nil
        setNeedsDisplay()
    }

    func makeMaskImage(size: CGSize, scale: CGFloat) -> UIImage? {
        guard hasContent else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let sx = size.width / bounds.width
        let sy = size.height / bounds.height
        return renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            UIColor.white.setStroke()
            for path in paths + [currentPath].compactMap({ $0 }) {
                let scaled = UIBezierPath(cgPath: path.cgPath)
                scaled.apply(CGAffineTransform(scaleX: sx, y: sy))
                scaled.lineWidth = brushWidth * max(sx, sy)
                scaled.lineCapStyle = .round
                scaled.lineJoinStyle = .round
                scaled.stroke()
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        let path = UIBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = brushWidth
        path.move(to: point)
        currentPath = path
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self),
              let path = currentPath else { return }
        path.addLine(to: point)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let path = currentPath {
            paths.append(path)
        }
        currentPath = nil
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    override func draw(_ rect: CGRect) {
        UIColor.white.withAlphaComponent(0.35).setStroke()
        for path in paths + [currentPath].compactMap({ $0 }) {
            path.lineWidth = brushWidth
            path.stroke()
        }
    }
}

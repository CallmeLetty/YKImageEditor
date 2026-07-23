import UIKit

final class DoodleDrawView: UIView {
    var strokeColor: UIColor = .systemRed {
        didSet { currentPathLayer?.strokeColor = strokeColor.cgColor }
    }

    var lineWidth: CGFloat = 6

    private var paths: [(UIBezierPath, UIColor)] = []
    private var currentPath: UIBezierPath?
    private var currentPathLayer: CAShapeLayer?

    var hasContent: Bool { !paths.isEmpty || currentPath != nil }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clear() {
        paths.removeAll()
        currentPath = nil
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        currentPathLayer = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        let path = UIBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = lineWidth
        path.move(to: point)
        currentPath = path

        let shape = CAShapeLayer()
        shape.strokeColor = strokeColor.cgColor
        shape.fillColor = UIColor.clear.cgColor
        shape.lineWidth = lineWidth
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.path = path.cgPath
        layer.addSublayer(shape)
        currentPathLayer = shape
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self),
              let path = currentPath else { return }
        path.addLine(to: point)
        currentPathLayer?.path = path.cgPath
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishStroke()
    }

    private func finishStroke() {
        if let path = currentPath {
            paths.append((path, strokeColor))
        }
        currentPath = nil
        currentPathLayer = nil
    }

    override func draw(_ rect: CGRect) {
        // 内容由 CAShapeLayer 绘制；snapshot 时 layer.render 即可。
    }
}

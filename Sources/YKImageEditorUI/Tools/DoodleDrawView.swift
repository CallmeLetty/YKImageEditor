import UIKit

final class DoodleStroke {
    let id: UUID
    var path: UIBezierPath
    let color: UIColor
    var lineWidth: CGFloat

    init(
        id: UUID = UUID(),
        path: UIBezierPath,
        color: UIColor,
        lineWidth: CGFloat
    ) {
        self.id = id
        self.path = UIBezierPath(cgPath: path.cgPath)
        self.color = color
        self.lineWidth = lineWidth
    }
}

final class DoodleDrawView: UIView {
    var strokeColor: UIColor = .systemRed {
        didSet { currentPathLayer?.strokeColor = strokeColor.cgColor }
    }

    var lineWidth: CGFloat = 6
    var onStrokeFinished: ((DoodleStroke) -> Void)?

    private var strokes: [DoodleStroke] = []
    private var currentPath: UIBezierPath?
    private var currentPathLayer: CAShapeLayer?
    private var currentStrokeColor: UIColor?
    private var currentLineWidth: CGFloat = 0

    var hasContent: Bool { !strokes.isEmpty || currentPath != nil }

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
        strokes.removeAll()
        currentPath = nil
        currentStrokeColor = nil
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        currentPathLayer = nil
    }

    func removeStroke(id: UUID) {
        guard let index = strokes.firstIndex(where: { $0.id == id }) else { return }
        strokes.remove(at: index)
        rebuildLayers()
    }

    func restoreStroke(_ stroke: DoodleStroke) {
        guard !strokes.contains(where: { $0.id == stroke.id }) else { return }
        strokes.append(stroke)
        layer.addSublayer(makeLayer(for: stroke))
    }

    func rescaleContent(from oldSize: CGSize, to newSize: CGSize) {
        guard oldSize.width > 0, oldSize.height > 0,
              newSize.width > 0, newSize.height > 0,
              oldSize != newSize else { return }
        let scaleX = newSize.width / oldSize.width
        let scaleY = newSize.height / oldSize.height
        let lineScale = min(scaleX, scaleY)
        for stroke in strokes {
            let path = UIBezierPath(cgPath: stroke.path.cgPath)
            path.apply(CGAffineTransform(scaleX: scaleX, y: scaleY))
            stroke.path = path
            stroke.lineWidth *= lineScale
        }
        rebuildLayers()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        let path = UIBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = lineWidth
        path.move(to: point)
        currentPath = path
        currentStrokeColor = strokeColor
        currentLineWidth = lineWidth

        let shape = makeLayer(path: path, color: strokeColor, lineWidth: lineWidth)
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
        if let path = currentPath, let color = currentStrokeColor {
            let stroke = DoodleStroke(
                path: path,
                color: color,
                lineWidth: currentLineWidth
            )
            strokes.append(stroke)
            onStrokeFinished?(stroke)
        }
        currentPath = nil
        currentStrokeColor = nil
        currentPathLayer = nil
    }

    private func rebuildLayers() {
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        for stroke in strokes {
            layer.addSublayer(makeLayer(for: stroke))
        }
    }

    private func makeLayer(for stroke: DoodleStroke) -> CAShapeLayer {
        makeLayer(path: stroke.path, color: stroke.color, lineWidth: stroke.lineWidth)
    }

    private func makeLayer(
        path: UIBezierPath,
        color: UIColor,
        lineWidth: CGFloat
    ) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.strokeColor = color.cgColor
        shape.fillColor = UIColor.clear.cgColor
        shape.lineWidth = lineWidth
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.path = path.cgPath
        return shape
    }

    override func draw(_ rect: CGRect) {
        // 内容由 CAShapeLayer 绘制；snapshot 时 layer.render 即可。
    }
}

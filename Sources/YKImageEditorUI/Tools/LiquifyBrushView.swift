import UIKit
import YKImageEditorCore

protocol LiquifyBrushViewDelegate: AnyObject {
    /// 返回图片在笔刷视图坐标系中的显示区域（需与画面一致）。
    func liquifyBrushViewRequestImageFrame(_ view: LiquifyBrushView) -> CGRect
    func liquifyBrushView(
        _ view: LiquifyBrushView,
        didStroke mode: LiquifyMode,
        at point: CGPoint,
        delta: CGPoint,
        radius: CGFloat,
        strength: CGFloat
    )
    func liquifyBrushViewDidEndStroke(_ view: LiquifyBrushView)
}

/// 液化笔刷手势层：在图片显示区域内涂抹。
final class LiquifyBrushView: UIView {
    weak var delegate: LiquifyBrushViewDelegate?

    var mode: LiquifyMode = .push
    /// 笔刷半径，相对于图片短边的比例。
    var brushRadiusRatio: CGFloat = 0.12
    var strength: CGFloat = 0.45

    private let brushLayer = CAShapeLayer()
    private var lastPoint: CGPoint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
        isHidden = true
        isUserInteractionEnabled = false

        brushLayer.fillColor = UIColor.clear.cgColor
        brushLayer.strokeColor = UIColor.white.withAlphaComponent(0.85).cgColor
        brushLayer.lineWidth = 1.5
        brushLayer.lineDashPattern = [4, 3]
        layer.addSublayer(brushLayer)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActive(_ active: Bool) {
        isHidden = !active
        isUserInteractionEnabled = active
        if !active {
            brushLayer.path = nil
            lastPoint = nil
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let imageFrame = currentImageFrame()
        guard imageFrame.width > 1, imageFrame.height > 1 else { return }

        let location = gesture.location(in: self)
        // 只在图片区域内生效，避免黑边手势映射错位
        guard imageFrame.insetBy(dx: -1, dy: -1).contains(location) else {
            if gesture.state == .ended || gesture.state == .cancelled {
                brushLayer.path = nil
                lastPoint = nil
                delegate?.liquifyBrushViewDidEndStroke(self)
            }
            return
        }

        switch gesture.state {
        case .began:
            lastPoint = location
            updateBrush(at: location, imageFrame: imageFrame)
            emit(at: location, previous: location, imageFrame: imageFrame)
        case .changed:
            updateBrush(at: location, imageFrame: imageFrame)
            if let last = lastPoint {
                emit(at: location, previous: last, imageFrame: imageFrame)
            }
            lastPoint = location
        case .ended, .cancelled, .failed:
            brushLayer.path = nil
            lastPoint = nil
            delegate?.liquifyBrushViewDidEndStroke(self)
        default:
            break
        }
    }

    private func currentImageFrame() -> CGRect {
        delegate?.liquifyBrushViewRequestImageFrame(self) ?? .zero
    }

    private func emit(at point: CGPoint, previous: CGPoint, imageFrame: CGRect) {
        let normalized = normalize(point, imageFrame: imageFrame)
        let prev = normalize(previous, imageFrame: imageFrame)
        // 用「屏幕像素」度量半径，再换算到归一化空间，保证圆形笔刷
        let shortSide = min(imageFrame.width, imageFrame.height)
        let radiusPx = brushRadiusRatio * shortSide
        // 传递各向同性的归一化半径：deformer 用宽高归一化距离时需配合各向异性修正
        // 这里改为把半径按短边归一化，并在 deformer 侧用宽高比修正（见 apply 调用处 strength/radius）
        let radius = radiusPx / shortSide

        let delta = CGPoint(x: normalized.x - prev.x, y: normalized.y - prev.y)
        if mode == .push {
            let dist = hypot(delta.x * imageFrame.width, delta.y * imageFrame.height)
            guard dist > 0.5 else { return }
        }

        delegate?.liquifyBrushView(
            self,
            didStroke: mode,
            at: normalized,
            delta: delta,
            radius: radius,
            strength: strength
        )
    }

    private func normalize(_ point: CGPoint, imageFrame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max((point.x - imageFrame.minX) / imageFrame.width, 0), 1),
            y: min(max((point.y - imageFrame.minY) / imageFrame.height, 0), 1)
        )
    }

    private func updateBrush(at point: CGPoint, imageFrame: CGRect) {
        let shortSide = min(imageFrame.width, imageFrame.height)
        let radius = brushRadiusRatio * shortSide
        brushLayer.path = UIBezierPath(
            arcCenter: point,
            radius: radius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).cgPath
    }
}

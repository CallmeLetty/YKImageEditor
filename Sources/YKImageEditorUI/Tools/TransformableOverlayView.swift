import UIKit

struct OverlayTransformState {
    let center: CGPoint
    let transform: CGAffineTransform
    let referenceSize: CGSize

    func isApproximatelyEqual(to other: OverlayTransformState) -> Bool {
        let epsilon: CGFloat = 0.001
        return abs(center.x - other.center.x) < epsilon
            && abs(center.y - other.center.y) < epsilon
            && abs(transform.a - other.transform.a) < epsilon
            && abs(transform.b - other.transform.b) < epsilon
            && abs(transform.c - other.transform.c) < epsilon
            && abs(transform.d - other.transform.d) < epsilon
            && abs(transform.tx - other.transform.tx) < epsilon
            && abs(transform.ty - other.transform.ty) < epsilon
    }
}

/// 可拖动、捏合缩放、双指旋转的文字/贴纸叠加视图。
final class TransformableOverlayView: UIView {
    var onTransformFinished: ((TransformableOverlayView, OverlayTransformState, OverlayTransformState) -> Void)?

    private var activeGestureCount = 0
    private var gestureStartState: OverlayTransformState?

    init(content: UIView, size: CGSize) {
        super.init(frame: CGRect(origin: .zero, size: size))
        addSubview(content)
        content.frame = bounds
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        isUserInteractionEnabled = true

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        pan.delegate = self
        pinch.delegate = self
        rotate.delegate = self
        addGestureRecognizer(pan)
        addGestureRecognizer(pinch)
        addGestureRecognizer(rotate)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var transformState: OverlayTransformState {
        OverlayTransformState(
            center: center,
            transform: transform,
            referenceSize: superview?.bounds.size ?? .zero
        )
    }

    func restoreTransformState(_ state: OverlayTransformState) {
        let currentSize = superview?.bounds.size ?? .zero
        guard state.referenceSize.width > 0, state.referenceSize.height > 0,
              currentSize.width > 0, currentSize.height > 0 else {
            center = state.center
            transform = state.transform
            return
        }
        let scaleX = currentSize.width / state.referenceSize.width
        let scaleY = currentSize.height / state.referenceSize.height
        let transformScale = min(scaleX, scaleY)
        center = CGPoint(x: state.center.x * scaleX, y: state.center.y * scaleY)
        transform = state.transform.scaledBy(x: transformScale, y: transformScale)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        updateGestureTransaction(for: gesture)
        let translation = gesture.translation(in: superview)
        if gesture.state == .changed || gesture.state == .ended {
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            gesture.setTranslation(.zero, in: superview)
        }
        finishGestureTransactionIfNeeded(for: gesture)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        updateGestureTransaction(for: gesture)
        if gesture.state == .changed || gesture.state == .ended {
            transform = transform.scaledBy(x: gesture.scale, y: gesture.scale)
            gesture.scale = 1
        }
        finishGestureTransactionIfNeeded(for: gesture)
    }

    @objc private func handleRotate(_ gesture: UIRotationGestureRecognizer) {
        updateGestureTransaction(for: gesture)
        if gesture.state == .changed || gesture.state == .ended {
            transform = transform.rotated(by: gesture.rotation)
            gesture.rotation = 0
        }
        finishGestureTransactionIfNeeded(for: gesture)
    }

    private func updateGestureTransaction(for gesture: UIGestureRecognizer) {
        guard gesture.state == .began else { return }
        if activeGestureCount == 0 {
            gestureStartState = transformState
        }
        activeGestureCount += 1
    }

    private func finishGestureTransactionIfNeeded(for gesture: UIGestureRecognizer) {
        guard gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed else { return }
        activeGestureCount = max(activeGestureCount - 1, 0)
        guard activeGestureCount == 0, let start = gestureStartState else { return }
        gestureStartState = nil
        let end = transformState
        guard !start.isApproximatelyEqual(to: end) else { return }
        onTransformFinished?(self, start, end)
    }
}

extension TransformableOverlayView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

enum OverlayFactory {
    static func textOverlay(text: String, color: UIColor) -> TransformableOverlayView {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = .boldSystemFont(ofSize: 28)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.sizeToFit()
        let size = CGSize(
            width: max(label.bounds.width + 16, 80),
            height: max(label.bounds.height + 12, 40)
        )
        label.frame = CGRect(origin: .zero, size: size)
        return TransformableOverlayView(content: label, size: size)
    }

    static func stickerOverlay(image: UIImage) -> TransformableOverlayView {
        let imageView = UIImageView(image: StickerImageRendering.resolvedImage(image))
        imageView.contentMode = .scaleAspectFit
        let side: CGFloat = 120
        let size = CGSize(width: side, height: side)
        imageView.frame = CGRect(origin: .zero, size: size)
        return TransformableOverlayView(content: imageView, size: size)
    }
}

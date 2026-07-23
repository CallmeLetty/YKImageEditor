import UIKit

/// 可拖动、捏合缩放、双指旋转的文字/贴纸叠加视图。
final class TransformableOverlayView: UIView {
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

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        if gesture.state == .changed || gesture.state == .ended {
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            gesture.setTranslation(.zero, in: superview)
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed || gesture.state == .ended {
            transform = transform.scaledBy(x: gesture.scale, y: gesture.scale)
            gesture.scale = 1
        }
    }

    @objc private func handleRotate(_ gesture: UIRotationGestureRecognizer) {
        if gesture.state == .changed || gesture.state == .ended {
            transform = transform.rotated(by: gesture.rotation)
            gesture.rotation = 0
        }
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
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        let side: CGFloat = 120
        let size = CGSize(width: side, height: side)
        imageView.frame = CGRect(origin: .zero, size: size)
        return TransformableOverlayView(content: imageView, size: size)
    }
}

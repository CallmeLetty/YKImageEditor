import AVFoundation
import UIKit

/// 展示工作图，并承载涂鸦 / 文字 / 贴纸 / 马赛克遮罩等叠加层。
final class EditorCanvasView: UIView {
    let imageView = UIImageView()
    let overlayContainer = UIView()
    let doodleView = DoodleDrawView()
    let mosaicMaskView = MosaicMaskView()

    private(set) var displayedImage: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        overlayContainer.isUserInteractionEnabled = true
        doodleView.isHidden = true
        mosaicMaskView.isHidden = true
        mosaicMaskView.backgroundColor = .clear
        mosaicMaskView.isOpaque = false

        addSubview(imageView)
        addSubview(overlayContainer)
        overlayContainer.addSubview(doodleView)
        overlayContainer.addSubview(mosaicMaskView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: UIImage?) {
        displayedImage = image
        imageView.image = image
        setNeedsLayout()
    }

    var imageFrame: CGRect {
        guard let image = displayedImage else { return .zero }
        return AVMakeRect(aspectRatio: image.size, insideRect: bounds)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        let frame = imageFrame
        overlayContainer.frame = frame
        doodleView.frame = overlayContainer.bounds
        mosaicMaskView.frame = overlayContainer.bounds
    }

    /// 将涂鸦与可变换叠加层栅格化并合成到当前图片上。
    func flattenOverlays(onto image: UIImage) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let overlayBounds = overlayContainer.bounds

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            guard overlayBounds.width > 0, overlayBounds.height > 0 else { return }

            if !doodleView.isHidden, doodleView.hasContent,
               let doodleImage = doodleView.snapshotImage() {
                doodleImage.draw(in: CGRect(origin: .zero, size: size))
            }

            for sub in overlayContainer.subviews {
                if sub is DoodleDrawView || sub is MosaicMaskView { continue }
                guard !sub.isHidden, let snap = sub.snapshotImage() else { continue }
                let center = CGPoint(
                    x: sub.center.x / overlayBounds.width * size.width,
                    y: sub.center.y / overlayBounds.height * size.height
                )
                let scaledSize = CGSize(
                    width: sub.bounds.width / overlayBounds.width * size.width,
                    height: sub.bounds.height / overlayBounds.height * size.height
                )
                let angle = atan2(sub.transform.b, sub.transform.a)
                let scale = hypot(sub.transform.a, sub.transform.c)

                guard let ctx = UIGraphicsGetCurrentContext() else { continue }
                ctx.saveGState()
                ctx.translateBy(x: center.x, y: center.y)
                ctx.rotate(by: angle)
                ctx.scaleBy(x: scale, y: scale)
                snap.draw(in: CGRect(
                    x: -scaledSize.width / 2,
                    y: -scaledSize.height / 2,
                    width: scaledSize.width,
                    height: scaledSize.height
                ))
                ctx.restoreGState()
            }
        }
    }

    func clearTransientOverlays() {
        doodleView.clear()
        mosaicMaskView.clear()
        for sub in overlayContainer.subviews where !(sub is DoodleDrawView || sub is MosaicMaskView) {
            sub.removeFromSuperview()
        }
    }
}

extension UIView {
    func snapshotImage() -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        return renderer.image { context in
            layer.render(in: context.cgContext)
        }
    }
}

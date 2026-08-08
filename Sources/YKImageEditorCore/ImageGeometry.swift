import CoreGraphics
import UIKit

/// 图片几何变换与降采样工具。
public enum ImageGeometry {
    /// 将图片等比缩小，使最长边不超过 `maxDimension`。
    ///
    /// - Parameters:
    ///   - image: 原图。
    ///   - maxDimension: 最长边上限；`<= 0` 时原样返回。
    /// - Returns: 降采样后的图片；若无需缩小则返回原图。
    public static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        guard maxDimension > 0 else { return image }
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        return render(image, size: target, transform: .identity)
    }

    /// 按归一化矩形裁剪（坐标系原点在左上，宽高为 0...1）。
    ///
    /// - Parameters:
    ///   - image: 原图。
    ///   - normalizedRect: 裁剪区域，会与 `CGRect(x:0,y:0,width:1,height:1)` 求交。
    public static func crop(_ image: UIImage, normalizedRect: CGRect) -> UIImage {
        let clamped = normalizedRect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else { return image }
        guard let cgImage = image.cgImage else { return image }

        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let rect = CGRect(
            x: floor(clamped.origin.x * pixelWidth),
            y: floor(clamped.origin.y * pixelHeight),
            width: floor(clamped.width * pixelWidth),
            height: floor(clamped.height * pixelHeight)
        )
        guard rect.width > 0, rect.height > 0,
              let cropped = cgImage.cropping(to: rect) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    /// 以 90° 的倍数旋转图片（顺时针，`quarterTurns` 可为负）。
    public static func rotate90(_ image: UIImage, quarterTurns: Int) -> UIImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0, let cgImage = image.cgImage else { return image }

        let radians = CGFloat(turns) * .pi / 2
        let bounds = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
        let size = CGSize(width: abs(bounds.width), height: abs(bounds.height))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: radians)
            let drawRect = CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            )
            ctx.draw(cgImage, in: drawRect)
        }
    }

    /// 水平或垂直翻转。
    public static func flip(_ image: UIImage, horizontal: Bool, vertical: Bool) -> UIImage {
        guard horizontal || vertical else { return image }
        let size = image.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            ctx.translateBy(
                x: horizontal ? size.width : 0,
                y: vertical ? size.height : 0
            )
            ctx.scaleBy(
                x: horizontal ? -1 : 1,
                y: vertical ? -1 : 1
            )
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 将方向规范化为 `.up`，避免后续像素操作受 EXIF 影响。
    public static func normalizedOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func render(_ image: UIImage, size: CGSize, transform: CGAffineTransform) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.concatenate(transform)
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

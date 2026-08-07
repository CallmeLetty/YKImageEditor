import CoreGraphics
import UIKit

/// 马赛克像素处理（Core Graphics）。
public enum MosaicProcessor {
    private static let rgbaBitmapInfo =
        CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

    /// 对整图应用方格马赛克。
    ///
    /// - Parameters:
    ///   - image: 原图。
    ///   - blockSize: 方格边长（像素，基于图片像素尺寸）。
    public static func pixelate(_ image: UIImage, blockSize: Int) -> UIImage {
        guard blockSize > 1 else { return image }
        guard let extracted = rgbaPixels(from: image) else { return image }
        let width = extracted.width
        let height = extracted.height
        var bytes = extracted.bytes
        let bytesPerRow = width * 4

        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let bw = min(blockSize, width - x)
                let bh = min(blockSize, height - y)
                let sampleIndex = ((y + bh / 2) * bytesPerRow) + (x + bw / 2) * 4
                let r = bytes[sampleIndex]
                let g = bytes[sampleIndex + 1]
                let b = bytes[sampleIndex + 2]
                let a = bytes[sampleIndex + 3]

                for dy in 0..<bh {
                    for dx in 0..<bw {
                        let index = ((y + dy) * bytesPerRow) + (x + dx) * 4
                        bytes[index] = r
                        bytes[index + 1] = g
                        bytes[index + 2] = b
                        bytes[index + 3] = a
                    }
                }
                x += blockSize
            }
            y += blockSize
        }

        return imageFromRGBA(bytes, width: width, height: height, scale: image.scale) ?? image
    }

    /// 仅在 `mask` 覆盖区域应用马赛克，其余保持原图。
    ///
    /// `mask` 应为与原图同尺寸的灰度/透明遮罩：不透明区域表示需要打码。
    public static func pixelate(_ image: UIImage, blockSize: Int, mask: UIImage) -> UIImage {
        let mosaicked = pixelate(image, blockSize: blockSize)
        guard let maskCG = mask.cgImage else { return mosaicked }

        let size = image.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            // 必须用 UIImage.draw；直接 cgContext.draw(cgImage) 会在 UIKit 坐标系下整图颠倒。
            image.draw(in: rect)

            let ctx = context.cgContext
            ctx.saveGState()
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.clip(to: rect, mask: maskCG)
            ctx.scaleBy(x: 1, y: -1)
            ctx.translateBy(x: 0, y: -size.height)
            mosaicked.draw(in: rect)
            ctx.restoreGState()
        }
    }

    /// 将 UIImage 绘制到「顶向下 RGBA」缓冲。
    private static func rgbaPixels(from image: UIImage) -> (bytes: [UInt8], width: Int, height: Int)? {
        let width = max(Int((image.size.width * image.scale).rounded()), 1)
        let height = max(Int((image.size.height * image.scale).rounded()), 1)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: rgbaBitmapInfo
        ) else {
            return nil
        }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        return (bytes, width, height)
    }

    private static func imageFromRGBA(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        scale: CGFloat
    ) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: rgbaBitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

import CoreGraphics
import UIKit

/// 马赛克像素处理（Core Graphics）。
public enum MosaicProcessor {
    /// 对整图应用方格马赛克。
    ///
    /// - Parameters:
    ///   - image: 原图。
    ///   - blockSize: 方格边长（像素，基于图片像素尺寸）。
    public static func pixelate(_ image: UIImage, blockSize: Int) -> UIImage {
        guard blockSize > 1, let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return image }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return image }
        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let bw = min(blockSize, width - x)
                let bh = min(blockSize, height - y)
                let sampleIndex = ((y + bh / 2) * width + (x + bw / 2)) * 4
                let r = ptr[sampleIndex]
                let g = ptr[sampleIndex + 1]
                let b = ptr[sampleIndex + 2]
                let a = ptr[sampleIndex + 3]

                for dy in 0..<bh {
                    for dx in 0..<bw {
                        let index = ((y + dy) * width + (x + dx)) * 4
                        ptr[index] = r
                        ptr[index + 1] = g
                        ptr[index + 2] = b
                        ptr[index + 3] = a
                    }
                }
                x += blockSize
            }
            y += blockSize
        }

        guard let output = context.makeImage() else { return image }
        return UIImage(cgImage: output, scale: image.scale, orientation: .up)
    }

    /// 仅在 `mask` 覆盖区域应用马赛克，其余保持原图。
    ///
    /// `mask` 应为与原图同尺寸的灰度/透明遮罩：不透明区域表示需要打码。
    public static func pixelate(_ image: UIImage, blockSize: Int, mask: UIImage) -> UIImage {
        let mosaicked = pixelate(image, blockSize: blockSize)
        guard let base = image.cgImage,
              let mosaic = mosaicked.cgImage,
              let maskCG = mask.cgImage else {
            return mosaicked
        }

        let size = image.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.draw(base, in: rect)
            context.cgContext.saveGState()
            context.cgContext.clip(to: rect, mask: maskCG)
            context.cgContext.draw(mosaic, in: rect)
            context.cgContext.restoreGState()
        }
    }
}

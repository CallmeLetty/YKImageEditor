import UIKit

/// 将 ``LiquifyDeformer`` 应用到图片上。
///
/// 形变场与触摸一致：归一化坐标原点在左上。
/// 像素缓冲统一为「行 0 = 顶部」的 RGBA（`byteOrder32Big` + `premultipliedLast`）。
public enum LiquifyProcessor {
    /// 与马赛克等工具区分：这里必须带 byte order，否则在小端上会变成 BGRA。
    private static let rgbaBitmapInfo =
        CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

    /// 渲染形变后的图片。
    public static func render(
        image: UIImage,
        deformer: LiquifyDeformer,
        maxDimension: CGFloat = 0
    ) -> UIImage {
        let source = maxDimension > 0
            ? ImageGeometry.downsample(image, maxDimension: maxDimension)
            : image
        guard deformer.hasDeformation else { return source }

        guard let extracted = rgbaPixels(from: source) else { return source }
        let width = extracted.width
        let height = extracted.height
        let src = extracted.bytes
        let bytesPerRow = width * 4
        var dst = [UInt8](repeating: 0, count: bytesPerRow * height)

        let maxX = CGFloat(max(width - 1, 1))
        let maxY = CGFloat(max(height - 1, 1))

        for y in 0..<height {
            let ny = CGFloat(y) / maxY
            let row = y * bytesPerRow
            for x in 0..<width {
                let nx = CGFloat(x) / maxX
                let sample = deformer.sourcePoint(forNormalized: CGPoint(x: nx, y: ny))
                let color = sampleBilinear(
                    src: src,
                    width: width,
                    height: height,
                    bytesPerRow: bytesPerRow,
                    x: sample.x * maxX,
                    y: sample.y * maxY
                )
                let di = row + x * 4
                dst[di] = color.0
                dst[di + 1] = color.1
                dst[di + 2] = color.2
                dst[di + 3] = color.3
            }
        }

        return imageFromRGBA(dst, width: width, height: height, scale: source.scale) ?? source
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

        // CG 默认原点在左下；翻转到 UIKit 后再 draw，使 bytes 行 0 = 画面顶部。
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
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private static func sampleBilinear(
        src: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        x: CGFloat,
        y: CGFloat
    ) -> (UInt8, UInt8, UInt8, UInt8) {
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = min(x0 + 1, width - 1)
        let y1 = min(y0 + 1, height - 1)
        let cx0 = min(max(x0, 0), width - 1)
        let cy0 = min(max(y0, 0), height - 1)
        let tx = Float(x - CGFloat(x0))
        let ty = Float(y - CGFloat(y0))

        func pixel(_ px: Int, _ py: Int) -> (Float, Float, Float, Float) {
            let i = py * bytesPerRow + px * 4
            return (Float(src[i]), Float(src[i + 1]), Float(src[i + 2]), Float(src[i + 3]))
        }

        let c00 = pixel(cx0, cy0)
        let c10 = pixel(x1, cy0)
        let c01 = pixel(cx0, y1)
        let c11 = pixel(x1, y1)

        func mix(_ a: Float, _ b: Float, _ t: Float) -> Float { a * (1 - t) + b * t }
        let r = mix(mix(c00.0, c10.0, tx), mix(c01.0, c11.0, tx), ty)
        let g = mix(mix(c00.1, c10.1, tx), mix(c01.1, c11.1, tx), ty)
        let b = mix(mix(c00.2, c10.2, tx), mix(c01.2, c11.2, tx), ty)
        let a = mix(mix(c00.3, c10.3, tx), mix(c01.3, c11.3, tx), ty)
        return (
            UInt8(clamping: Int(r.rounded())),
            UInt8(clamping: Int(g.rounded())),
            UInt8(clamping: Int(b.rounded())),
            UInt8(clamping: Int(a.rounded()))
        )
    }
}

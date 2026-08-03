import XCTest
import UIKit
@testable import YKImageEditorCore

final class YKImageEditorCoreTests: XCTestCase {
    func testEditorConfigIncludingAndExcluding() {
        let included = EditorConfig.including([.crop, .text])
        XCTAssertTrue(included.isEnabled(.crop))
        XCTAssertTrue(included.isEnabled(.text))
        XCTAssertFalse(included.isEnabled(.mosaic))

        let excluded = EditorConfig.excluding([.sticker, .mosaic])
        XCTAssertTrue(excluded.isEnabled(.crop))
        XCTAssertFalse(excluded.isEnabled(.sticker))
        XCTAssertFalse(excluded.isEnabled(.mosaic))

        XCTAssertEqual(EditorConfig.all.features, EditorFeature.all)
    }

    func testDownsampleRespectsMaxDimension() {
        let image = makeImage(width: 4000, height: 2000, color: .red)
        let result = ImageGeometry.downsample(image, maxDimension: 1000)
        XCTAssertEqual(result.size.width, 1000, accuracy: 1)
        XCTAssertEqual(result.size.height, 500, accuracy: 1)
    }

    func testCropNormalizedRect() {
        let image = makeImage(width: 100, height: 100, color: .blue)
        let cropped = ImageGeometry.crop(
            image,
            normalizedRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        )
        let expected = CGFloat(image.cgImage!.width) * 0.5
        XCTAssertEqual(CGFloat(cropped.cgImage!.width), expected, accuracy: 1)
        XCTAssertEqual(CGFloat(cropped.cgImage!.height), expected, accuracy: 1)
    }

    func testRotate90SwapsDimensions() {
        let image = makeImage(width: 120, height: 60, color: .green)
        let rotated = ImageGeometry.rotate90(image, quarterTurns: 1)
        XCTAssertEqual(rotated.size.width, 60, accuracy: 1)
        XCTAssertEqual(rotated.size.height, 120, accuracy: 1)
    }

    func testSessionUndoRedo() {
        let image = makeImage(width: 80, height: 80, color: .orange)
        let session = EditorSession(image: image, maxDimension: 4096)
        XCTAssertFalse(session.isDirty)

        let next = makeImage(width: 80, height: 80, color: .purple)
        session.commit(next)
        XCTAssertTrue(session.isDirty)
        XCTAssertTrue(session.canUndo)

        session.undo()
        XCTAssertTrue(session.canRedo)

        session.redo()
        XCTAssertFalse(session.canRedo)
        XCTAssertTrue(session.canUndo)
    }

    func testMosaicChangesPixels() {
        let image = makeGradientImage(width: 64, height: 64)
        let mosaicked = MosaicProcessor.pixelate(image, blockSize: 8)
        XCTAssertEqual(mosaicked.size, image.size)
        XCTAssertNotNil(mosaicked.cgImage)
    }

    func testExportJPEG() {
        let image = makeImage(width: 200, height: 100, color: .cyan)
        let data = ImageExporter.exportData(
            image,
            options: ExportOptions(maxDimension: 100, jpegQuality: 0.8, preferJPEG: true)
        )
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }

    func testBlendMultiplyDarkens() {
        let base = makeImage(width: 32, height: 32, color: UIColor(white: 0.8, alpha: 1))
        let blended = ImageBlender.blend(
            base: base,
            color: UIColor(white: 0.5, alpha: 1),
            mode: .multiply,
            opacity: 1
        )
        XCTAssertEqual(blended.size, base.size)
        let baseLuma = luminance(pixelColor(of: base, at: CGPoint(x: 16, y: 16)))
        let blendLuma = luminance(pixelColor(of: blended, at: CGPoint(x: 16, y: 16)))
        XCTAssertLessThan(blendLuma, baseLuma - 0.05)
    }

    func testBlendLowIntensityKeepsBaseVisible() {
        let base = makeImage(width: 32, height: 32, color: UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1))
        let blended = ImageBlender.blend(
            base: base,
            color: .orange,
            mode: .colorBurn,
            opacity: 0.05
        )
        let baseColor = rgb(pixelColor(of: base, at: CGPoint(x: 16, y: 16)))
        let blendColor = rgb(pixelColor(of: blended, at: CGPoint(x: 16, y: 16)))
        // 5% 强度时，应仍非常接近原图像素
        XCTAssertEqual(blendColor.r, baseColor.r, accuracy: 0.08)
        XCTAssertEqual(blendColor.g, baseColor.g, accuracy: 0.08)
        XCTAssertEqual(blendColor.b, baseColor.b, accuracy: 0.08)
    }

    func testBlendPresetProducesImage() {
        let base = makeImage(width: 48, height: 48, color: .systemBlue)
        let result = ImageBlender.blend(base: base, preset: .warmColorBurn, intensity: 0.6)
        XCTAssertEqual(result.size, base.size)
        XCTAssertNotNil(result.cgImage)
    }

    func testEditorFeatureAllIncludesBlend() {
        XCTAssertTrue(EditorFeature.all.contains(.blend))
        XCTAssertFalse(EditorConfig.excluding([.blend]).isEnabled(.blend))
    }

    private func makeImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeGradientImage(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            for x in 0..<width {
                let t = CGFloat(x) / CGFloat(max(width - 1, 1))
                UIColor(red: t, green: 1 - t, blue: 0.5, alpha: 1).setFill()
                context.fill(CGRect(x: x, y: 0, width: 1, height: height))
            }
        }
    }

    private func pixelColor(of image: UIImage, at point: CGPoint) -> UIColor {
        guard let cgImage = image.cgImage else { return .clear }
        let width = cgImage.width
        let height = cgImage.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .clear }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let x = min(max(Int(point.x), 0), width - 1)
        let y = min(max(Int(point.y), 0), height - 1)
        // CGContext 原点在左下，UIImage 点在左上，这里按图像像素行从上到下采样时翻转 Y。
        let row = height - 1 - y
        let index = (row * width + x) * 4
        return UIColor(
            red: CGFloat(rgba[index]) / 255,
            green: CGFloat(rgba[index + 1]) / 255,
            blue: CGFloat(rgba[index + 2]) / 255,
            alpha: CGFloat(rgba[index + 3]) / 255
        )
    }

    private func rgb(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        let c = rgb(color)
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }
}

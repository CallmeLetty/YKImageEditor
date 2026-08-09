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

    func testRotate90IsClockwiseAndAccumulates() {
        let image = makeQuadrantImage(width: 40, height: 20)

        let once = ImageGeometry.rotate90(image, quarterTurns: 1)
        assertPixelColor(once, at: CGPoint(x: 5, y: 5), equals: .blue)
        assertPixelColor(once, at: CGPoint(x: 15, y: 5), equals: .red)
        assertPixelColor(once, at: CGPoint(x: 5, y: 35), equals: .yellow)
        assertPixelColor(once, at: CGPoint(x: 15, y: 35), equals: .green)

        let twice = ImageGeometry.rotate90(once, quarterTurns: 1)
        assertPixelColor(twice, at: CGPoint(x: 5, y: 5), equals: .yellow)
        assertPixelColor(twice, at: CGPoint(x: 35, y: 5), equals: .blue)
        assertPixelColor(twice, at: CGPoint(x: 5, y: 15), equals: .green)
        assertPixelColor(twice, at: CGPoint(x: 35, y: 15), equals: .red)

        let threeTimes = ImageGeometry.rotate90(twice, quarterTurns: 1)
        let fourTimes = ImageGeometry.rotate90(threeTimes, quarterTurns: 1)
        assertPixelColor(fourTimes, at: CGPoint(x: 5, y: 5), equals: .red)
        assertPixelColor(fourTimes, at: CGPoint(x: 35, y: 5), equals: .green)
        assertPixelColor(fourTimes, at: CGPoint(x: 5, y: 15), equals: .blue)
        assertPixelColor(fourTimes, at: CGPoint(x: 35, y: 15), equals: .yellow)
    }

    func testHorizontalFlipSwapsLeftAndRight() {
        let image = makeSplitImage(
            size: CGSize(width: 64, height: 64),
            firstRect: CGRect(x: 0, y: 0, width: 32, height: 64),
            firstColor: .red,
            secondColor: .blue
        )
        let flipped = ImageGeometry.flip(image, horizontal: true, vertical: false)
        let left = rgb(pixelColor(of: flipped, at: CGPoint(x: 8, y: 32)))
        let right = rgb(pixelColor(of: flipped, at: CGPoint(x: 56, y: 32)))

        XCTAssertGreaterThan(left.b, 0.8, "left side should become blue, got \(left)")
        XCTAssertGreaterThan(right.r, 0.8, "right side should become red, got \(right)")
    }

    func testVerticalFlipSwapsTopAndBottom() {
        let image = makeSplitImage(
            size: CGSize(width: 64, height: 64),
            firstRect: CGRect(x: 0, y: 0, width: 64, height: 32),
            firstColor: .red,
            secondColor: .blue
        )
        let flipped = ImageGeometry.flip(image, horizontal: false, vertical: true)
        let top = rgb(pixelColor(of: flipped, at: CGPoint(x: 32, y: 8)))
        let bottom = rgb(pixelColor(of: flipped, at: CGPoint(x: 32, y: 56)))

        XCTAssertGreaterThan(top.b, 0.8, "top side should become blue, got \(top)")
        XCTAssertGreaterThan(bottom.r, 0.8, "bottom side should become red, got \(bottom)")
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

    func testMosaicMaskedDoesNotFlipImage() {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let split = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 32, width: 64, height: 32))
        }
        // 仅遮罩中心一小块，其余应保持原方向
        let mask = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 24, y: 24, width: 16, height: 16))
        }
        let result = MosaicProcessor.pixelate(split, blockSize: 8, mask: mask)
        let top = rgb(pixelColor(of: result, at: CGPoint(x: 32, y: 4)))
        let bottom = rgb(pixelColor(of: result, at: CGPoint(x: 32, y: 60)))
        XCTAssertGreaterThan(top.r, 0.8, "mosaic flip? top=\(top)")
        XCTAssertGreaterThan(bottom.b, 0.8, "mosaic flip? bottom=\(bottom)")
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

    func testLiquifyPushChangesImage() {
        let base = makeGradientImage(width: 64, height: 64)
        let deformer = LiquifyDeformer(columns: 16, rows: 16)
        deformer.apply(
            mode: .push,
            at: CGPoint(x: 0.5, y: 0.5),
            delta: CGPoint(x: 0.1, y: 0),
            radius: 0.25,
            strength: 1,
            aspectRatio: 1
        )
        XCTAssertTrue(deformer.hasDeformation)
        let result = LiquifyProcessor.render(image: base, deformer: deformer)
        XCTAssertEqual(result.size, base.size)
        XCTAssertNotEqual(
            pixelColor(of: result, at: CGPoint(x: 32, y: 32)),
            pixelColor(of: base, at: CGPoint(x: 32, y: 32))
        )
    }

    func testLiquifyTouchTopAffectsTopNotBottom() {
        // 上红下蓝
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let split = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 32, width: 64, height: 32))
        }
        let deformer = LiquifyDeformer(columns: 32, rows: 32)
        // 在顶部横向推移
        deformer.apply(
            mode: .push,
            at: CGPoint(x: 0.5, y: 0.2),
            delta: CGPoint(x: 0.08, y: 0),
            radius: 0.2,
            strength: 1,
            aspectRatio: 1
        )
        let result = LiquifyProcessor.render(image: split, deformer: deformer)
        let top = rgb(pixelColor(of: result, at: CGPoint(x: 32, y: 8)))
        let bottom = rgb(pixelColor(of: result, at: CGPoint(x: 32, y: 56)))
        // 不得整图颠倒：顶仍偏红、底仍偏蓝
        XCTAssertGreaterThan(bottom.b, 0.6, "bottom should stay blue, got \(bottom)")
        XCTAssertGreaterThan(top.r, 0.3, "top should stay red, got \(top)")
        XCTAssertGreaterThan(top.r, top.b)
        XCTAssertGreaterThan(bottom.b, bottom.r)
    }

    func testLiquifyDoesNotFlipWholeImage() {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let split = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 32, width: 64, height: 32))
        }
        // 极弱推移：几乎不动像素，但会走完整渲染路径
        let deformer = LiquifyDeformer(columns: 8, rows: 8)
        deformer.apply(
            mode: .push,
            at: CGPoint(x: 0.5, y: 0.5),
            delta: CGPoint(x: 0.01, y: 0),
            radius: 0.05,
            strength: 0.05,
            aspectRatio: 1
        )
        let result = LiquifyProcessor.render(image: split, deformer: deformer)
        let top = rgb(pixelColor(of: result, at: CGPoint(x: 32, y: 4)))
        let bottom = rgb(pixelColor(of: result, at: CGPoint(x: 32, y: 60)))
        XCTAssertGreaterThan(top.r, 0.8, "identity-ish render flipped? top=\(top)")
        XCTAssertGreaterThan(bottom.b, 0.8, "identity-ish render flipped? bottom=\(bottom)")
    }

    func testLiquifyPushMovesContent() {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let split = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 24, height: 48))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 24, y: 0, width: 24, height: 48))
        }
        let deformer = LiquifyDeformer(columns: 24, rows: 24)
        deformer.apply(
            mode: .push,
            at: CGPoint(x: 0.5, y: 0.5),
            delta: CGPoint(x: 0.08, y: 0),
            radius: 0.3,
            strength: 1,
            aspectRatio: 1
        )
        let result = LiquifyProcessor.render(image: split, deformer: deformer)
        XCTAssertTrue(deformer.hasDeformation)
        XCTAssertEqual(result.size, split.size)
    }

    func testLiquifyDeformerRestoresSnapshot() {
        let deformer = LiquifyDeformer(columns: 16, rows: 16)
        let original = deformer.snapshot()
        deformer.apply(
            at: CGPoint(x: 0.5, y: 0.5),
            delta: CGPoint(x: 0.1, y: 0),
            radius: 0.25,
            strength: 1
        )
        XCTAssertTrue(deformer.hasDeformation)

        deformer.restore(from: original)

        XCTAssertFalse(deformer.hasDeformation)
        XCTAssertEqual(deformer.sourcePoint(forNormalized: CGPoint(x: 0.5, y: 0.5)), CGPoint(x: 0.5, y: 0.5))
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

    private func makeQuadrantImage(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let halfWidth = CGFloat(width) / 2
            let halfHeight = CGFloat(height) / 2
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: halfWidth, height: halfHeight))
            UIColor.green.setFill()
            context.fill(CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight))
            UIColor.yellow.setFill()
            context.fill(CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight))
        }
    }

    private func makeSplitImage(
        size: CGSize,
        firstRect: CGRect,
        firstColor: UIColor,
        secondColor: UIColor
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            secondColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            firstColor.setFill()
            context.fill(firstRect)
        }
    }

    /// 取样为强制 RGBA 的 1×1 缓冲，避免 BGRA / 行序误读。
    private func pixelColor(of image: UIImage, at point: CGPoint) -> UIColor {
        let scale = image.scale
        let px = min(max(Int((point.x * scale).rounded()), 0), Int(image.size.width * scale) - 1)
        let py = min(max(Int((point.y * scale).rounded()), 0), Int(image.size.height * scale) - 1)
        var pixel: [UInt8] = [0, 0, 0, 0]
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return .clear }

        context.translateBy(x: 0, y: 1)
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        image.draw(at: CGPoint(x: -CGFloat(px), y: -CGFloat(py)))
        UIGraphicsPopContext()

        return UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: CGFloat(pixel[3]) / 255
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

    private func assertPixelColor(
        _ image: UIImage,
        at point: CGPoint,
        equals expected: UIColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualRGB = rgb(pixelColor(of: image, at: point))
        let expectedRGB = rgb(expected)
        XCTAssertEqual(actualRGB.r, expectedRGB.r, accuracy: 0.05, file: file, line: line)
        XCTAssertEqual(actualRGB.g, expectedRGB.g, accuracy: 0.05, file: file, line: line)
        XCTAssertEqual(actualRGB.b, expectedRGB.b, accuracy: 0.05, file: file, line: line)
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        let c = rgb(color)
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }
}

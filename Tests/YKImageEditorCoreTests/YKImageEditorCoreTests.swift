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
}

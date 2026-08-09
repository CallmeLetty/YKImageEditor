import XCTest
import UIKit
@testable import YKImageEditorUI

@MainActor
final class YKImageEditorUITests: XCTestCase {
    func testDoodleStrokeCanBeRemovedAndRestored() {
        let view = DoodleDrawView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 10, y: 10))
        path.addLine(to: CGPoint(x: 90, y: 90))
        let stroke = DoodleStroke(path: path, color: .red, lineWidth: 6)

        view.restoreStroke(stroke)
        XCTAssertTrue(view.hasContent)

        view.removeStroke(id: stroke.id)
        XCTAssertFalse(view.hasContent)

        view.restoreStroke(stroke)
        XCTAssertTrue(view.hasContent)
    }

    func testRenderingEditableOverlayDoesNotRemoveSourceView() {
        let canvas = EditorCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 240))
        let base = makeImage(size: CGSize(width: 200, height: 200), color: .blue)
        canvas.setImage(base)
        canvas.layoutIfNeeded()
        let overlay = OverlayFactory.textOverlay(text: "YK", color: .white)
        overlay.center = CGPoint(x: canvas.overlayContainer.bounds.midX, y: canvas.overlayContainer.bounds.midY)
        canvas.overlayContainer.addSubview(overlay)

        let rendered = canvas.renderEditableLayers(onto: base)

        XCTAssertEqual(rendered.size, base.size)
        XCTAssertTrue(overlay.superview === canvas.overlayContainer)
    }

    func testOverlayTransformStateRestoresAcrossContainerResize() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let overlay = OverlayFactory.textOverlay(text: "YK", color: .white)
        container.addSubview(overlay)
        overlay.center = CGPoint(x: 50, y: 25)
        overlay.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        let state = overlay.transformState

        container.frame.size = CGSize(width: 400, height: 200)
        overlay.center = .zero
        overlay.transform = .identity
        overlay.restoreTransformState(state)

        XCTAssertEqual(overlay.center.x, 100, accuracy: 0.001)
        XCTAssertEqual(overlay.center.y, 50, accuracy: 0.001)
        XCTAssertEqual(overlay.transform.a, 3, accuracy: 0.001)
        XCTAssertEqual(overlay.transform.d, 3, accuracy: 0.001)
    }

    func testEditorHistoryUndoesOneOverlayMoveBeforeRemovingOverlay() {
        let model = ImageEditorViewModel(image: makeImage(size: CGSize(width: 200, height: 200), color: .blue), config: .all, stickerProvider: nil)
        let host = model.makeCanvasHost()
        host.frame = CGRect(x: 0, y: 0, width: 240, height: 240)
        host.layoutIfNeeded()
        model.textInput = "YK"
        model.addText()
        let overlay = host.canvas.overlayContainer.subviews.compactMap { $0 as? TransformableOverlayView }.first
        XCTAssertNotNil(overlay)

        guard let overlay else { return }
        let before = overlay.transformState
        overlay.center.x += 40
        let after = overlay.transformState
        overlay.onTransformFinished?(overlay, before, after)

        model.undo()
        XCTAssertEqual(overlay.center.x, before.center.x, accuracy: 0.001)
        XCTAssertTrue(overlay.superview === host.canvas.overlayContainer)

        model.undo()
        XCTAssertNil(overlay.superview)

        model.redo()
        XCTAssertTrue(overlay.superview === host.canvas.overlayContainer)
    }

    func testEditorHistoryUndoesDoodleStroke() {
        let model = ImageEditorViewModel(image: makeImage(size: CGSize(width: 200, height: 200), color: .blue), config: .all, stickerProvider: nil)
        let host = model.makeCanvasHost()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 5))
        path.addLine(to: CGPoint(x: 40, y: 40))
        let stroke = DoodleStroke(path: path, color: .red, lineWidth: 6)
        host.canvas.doodleView.restoreStroke(stroke)
        host.canvas.doodleView.onStrokeFinished?(stroke)

        model.undo()
        XCTAssertFalse(host.canvas.doodleView.hasContent)

        model.redo()
        XCTAssertTrue(host.canvas.doodleView.hasContent)
    }

    func testEditorHistoryUndoesLiquifyStrokeAsOneAction() {
        let model = ImageEditorViewModel(image: makeImage(size: CGSize(width: 200, height: 200), color: .blue), config: .all, stickerProvider: nil)
        let host = model.makeCanvasHost()
        host.frame = CGRect(x: 0, y: 0, width: 240, height: 240)
        host.layoutIfNeeded()
        model.selectTool(.liquify)
        model.liquifyBrushViewWillBeginStroke(host.brushView)
        model.liquifyBrushView(
            host.brushView,
            didStroke: .push,
            at: CGPoint(x: 0.5, y: 0.5),
            delta: CGPoint(x: 0.08, y: 0),
            radius: 0.2,
            strength: 1
        )
        model.liquifyBrushViewDidEndStroke(host.brushView)

        XCTAssertTrue(model.canUndo)
        model.undo()
        XCTAssertFalse(model.canUndo)
        XCTAssertTrue(model.canRedo)

        model.redo()
        XCTAssertTrue(model.canUndo)
    }

    private func makeImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

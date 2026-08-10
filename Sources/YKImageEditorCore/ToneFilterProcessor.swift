import CoreImage
import UIKit

/// 使用 Core Image 应用曝光、色彩和明暗区域调整。
public enum ToneFilterProcessor {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    public static func render(
        image: UIImage,
        parameters: ToneFilterParameters,
        maxDimension: CGFloat = 0
    ) -> UIImage {
        if parameters.isIdentity {
            return maxDimension > 0
                ? ImageGeometry.downsample(image, maxDimension: maxDimension)
                : image
        }
        let normalized = ImageGeometry.normalizedOrientation(image)
        let source = maxDimension > 0
            ? ImageGeometry.downsample(normalized, maxDimension: maxDimension)
            : normalized
        guard let input = makeCIImage(from: source) else { return source }

        var output = input
        output = applyingExposure(to: output, value: parameters.exposure)
        output = applyingHighlightsAndShadows(
            to: output,
            highlights: parameters.highlights,
            shadows: parameters.shadows
        )
        output = applyingTemperature(to: output, value: parameters.temperature)
        output = applyingColorControls(
            to: output,
            brightness: parameters.brightness,
            contrast: parameters.contrast,
            saturation: parameters.saturation
        )

        guard let rendered = context.createCGImage(output, from: input.extent) else { return source }
        return UIImage(cgImage: rendered, scale: source.scale, orientation: .up)
    }

    private static func makeCIImage(from image: UIImage) -> CIImage? {
        if let ciImage = image.ciImage {
            return ciImage
        }
        if let cgImage = image.cgImage {
            return CIImage(cgImage: cgImage)
        }
        return nil
    }

    private static func applyingExposure(to image: CIImage, value: Float) -> CIImage {
        let value = min(max(value, -2), 2)
        guard value != 0,
              let filter = CIFilter(name: "CIExposureAdjust", parameters: [
                  kCIInputImageKey: image,
                  kCIInputEVKey: value
              ]),
              let output = filter.outputImage else {
            return image
        }
        return output
    }

    private static func applyingHighlightsAndShadows(
        to image: CIImage,
        highlights: Float,
        shadows: Float
    ) -> CIImage {
        let highlights = min(max(highlights, -1), 1)
        let shadows = min(max(shadows, -1), 1)
        guard highlights != 0 || shadows != 0,
              let filter = CIFilter(name: "CIToneCurve", parameters: [
                  kCIInputImageKey: image,
                  "inputPoint0": CIVector(x: 0, y: 0),
                  "inputPoint1": CIVector(x: 0.25, y: CGFloat(0.25 + shadows * 0.2)),
                  "inputPoint2": CIVector(x: 0.5, y: 0.5),
                  "inputPoint3": CIVector(x: 0.75, y: CGFloat(0.75 + highlights * 0.2)),
                  "inputPoint4": CIVector(x: 1, y: 1)
              ]),
              let output = filter.outputImage else {
            return image
        }
        return output
    }

    private static func applyingTemperature(to image: CIImage, value: Float) -> CIImage {
        let value = min(max(value, -1), 1)
        guard value != 0,
              let filter = CIFilter(name: "CITemperatureAndTint", parameters: [
                  kCIInputImageKey: image,
                  "inputNeutral": CIVector(x: 6500, y: 0),
                  "inputTargetNeutral": CIVector(x: CGFloat(6500 + value * 2500), y: 0)
              ]),
              let output = filter.outputImage else {
            return image
        }
        return output
    }

    private static func applyingColorControls(
        to image: CIImage,
        brightness: Float,
        contrast: Float,
        saturation: Float
    ) -> CIImage {
        let brightness = min(max(brightness, -1), 1)
        let contrast = min(max(1 + contrast, 0), 2)
        let saturation = min(max(1 + saturation, 0), 2)
        guard brightness != 0 || contrast != 1 || saturation != 1,
              let filter = CIFilter(name: "CIColorControls", parameters: [
                  kCIInputImageKey: image,
                  kCIInputBrightnessKey: brightness,
                  kCIInputContrastKey: contrast,
                  kCIInputSaturationKey: saturation
              ]),
              let output = filter.outputImage else {
            return image
        }
        return output
    }
}

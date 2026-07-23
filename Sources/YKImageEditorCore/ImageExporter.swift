import UIKit

/// 将工作图按 ``ExportOptions`` 编码为最终 `UIImage`。
public enum ImageExporter {
    /// 导出图片。
    ///
    /// - Parameters:
    ///   - image: 编辑完成后的工作图。
    ///   - options: 导出选项。
    /// - Returns: 按选项降采样并重新编码后的图片。
    public static func export(_ image: UIImage, options: ExportOptions) -> UIImage {
        let scaled = ImageGeometry.downsample(image, maxDimension: options.maxDimension)
        guard let data = encode(scaled, options: options),
              let result = UIImage(data: data) else {
            return scaled
        }
        return result
    }

    /// 导出原始编码数据（JPEG 或 PNG）。
    public static func exportData(_ image: UIImage, options: ExportOptions) -> Data? {
        let scaled = ImageGeometry.downsample(image, maxDimension: options.maxDimension)
        return encode(scaled, options: options)
    }

    private static func encode(_ image: UIImage, options: ExportOptions) -> Data? {
        if options.preferJPEG {
            return image.jpegData(compressionQuality: options.jpegQuality)
        }
        return image.pngData()
    }
}

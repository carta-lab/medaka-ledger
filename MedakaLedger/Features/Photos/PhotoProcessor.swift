import Foundation
import ImageIO
import UniformTypeIdentifiers

// 写真の縮小（PRD.md F9）。長辺1600pxへ縮小し、1枚あたり500KBを目安にJPEGへ圧縮する。サムネイルは長辺320px。
// 端末の写真ライブラリには書き込まない。メインスレッドの外（Task.detached）で呼ぶ。

enum PhotoProcessor {
    /// 元の画像データを縮小したJPEGとサムネイルにする。画像として読めなければ nil。
    /// 撮影日はEXIFの撮影日時、無ければ fallbackDate（撮影した時刻や取り込んだ時刻）を使う。
    static func process(_ data: Data, fallbackDate: Date) -> ProcessedPhoto? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let size = pixelSize(of: source),
              let full = downsample(source, size: size, maxPixel: PhotoRules.maxLongSide),
              let thumbnail = downsample(source, size: size, maxPixel: PhotoRules.thumbnailLongSide),
              let jpeg = encode(full, qualities: PhotoRules.jpegQualities, budget: PhotoRules.byteBudget),
              let thumbnailData = encode(thumbnail, qualities: [0.7], budget: Int.max)
        else { return nil }
        return ProcessedPhoto(jpegData: jpeg, thumbnailData: thumbnailData, capturedAt: captureDate(of: source) ?? fallbackDate)
    }

    private static func pixelSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { return nil }
        return (width, height)
    }

    /// 向き（EXIF）を反映して縮小する。元より大きくはしない。
    private static func downsample(_ source: CGImageSource, size: (width: Int, height: Int), maxPixel: Int) -> CGImage? {
        let target = PhotoRules.fittedSize(width: size.width, height: size.height, maxLongSide: maxPixel)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(target.width, target.height),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// 品質を上から順に試して、目安の大きさに収まった最初のものを返す。どれも収まらなければ最後のもの。
    private static func encode(_ image: CGImage, qualities: [Double], budget: Int) -> Data? {
        var last: Data?
        for quality in qualities {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { return nil }
            let data = output as Data
            last = data
            if data.count <= budget { return data }
        }
        return last
    }

    private static func captureDate(of source: CGImageSource) -> Date? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let text = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }
}

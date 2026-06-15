import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Downsample photos before upload. Progress/feed photos off a modern phone are
/// 3–8 MB; shrinking to a sensible max dimension cuts upload time, storage, and
/// every later download — without a visible quality hit on a phone screen.
enum ImageProcessing {
    static func downsampledJPEG(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return data // not decodable as an image — upload as-is
        }
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // respect EXIF orientation
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, downsampleOptions as CFDictionary) else {
            return data
        }
        let image = UIImage(cgImage: cg)
        return image.jpegData(compressionQuality: quality) ?? data
    }
}

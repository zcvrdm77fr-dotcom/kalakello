import UIKit

enum ImageTools {
    /// Downscales to at most `maxSide` px on the long edge and re-encodes as JPEG
    /// (also strips EXIF/GPS, because only pixel data is re-drawn).
    static func downscaledJPEG(_ data: Data, maxSide: CGFloat = 1400) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let output = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return output.jpegData(compressionQuality: 0.8)
    }
}

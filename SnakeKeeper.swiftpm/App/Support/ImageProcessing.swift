import UIKit

enum ImageProcessing {
    /// Downscaled full image and thumbnail as JPEG, to keep the store small.
    static func prepare(_ data: Data) -> (image: Data, thumbnail: Data)? {
        guard let image = UIImage(data: data) else { return nil }
        return prepare(image)
    }

    static func prepare(_ image: UIImage) -> (image: Data, thumbnail: Data)? {
        guard let full = resized(image, maxDimension: 2048).jpegData(compressionQuality: 0.8),
              let thumb = resized(image, maxDimension: 300).jpegData(compressionQuality: 0.7)
        else { return nil }
        return (full, thumb)
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return image }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

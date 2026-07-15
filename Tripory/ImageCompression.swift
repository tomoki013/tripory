import UIKit

/// 旅の写真を保存する前に、表示に十分な解像度までリサイズしてJPEG圧縮する。
/// 端末の元写真(数MB〜十数MB)をそのまま保存すると容量を圧迫するため。
enum ImageCompression {
    static func compress(_ data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

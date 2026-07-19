import UIKit

/// 旅の写真を保存する前に、表示に十分な解像度までリサイズしてJPEG圧縮する。
/// 端末の元写真(数MB〜十数MB)をそのまま保存すると容量を圧迫するため。
enum ImageCompression {
    /// maxDimensionは「長辺のピクセル数」。UIImage.sizeはポイント基準で、
    /// レンダラも既定では端末の解像度倍率(2〜3倍)で描くため、
    /// どちらも実ピクセルに揃えないと意図の数倍の大きさで保存されてしまう。
    static func compress(_ data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let pixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }

        let ratio = min(1, maxDimension / max(pixelSize.width, pixelSize.height))
        let targetSize = CGSize(width: pixelSize.width * ratio, height: pixelSize.height * ratio)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

import UIKit

/// `-seedDemo` で使う、写真の代わりの手続き的な画像。
/// 実写真は同梱しておらず、本番ではユーザーが写真ライブラリから選んだものだけを保存する。
/// 平坦な単色グラデーションだと「写真主導のUI」の見え方が判断できないため、
/// 空・光・かすみ・ビネットを重ねて写真らしい奥行きを作る。
enum DemoPhotoFactory {

    /// 訪問先ごとに色味の違う1枚。seedを変えると別の風景色になる。
    static func travelPhoto(seed: Int, size: CGSize = CGSize(width: 1_200, height: 900)) -> Data? {
        let hue = CGFloat((seed &* 47) % 360) / 360
        return render(size: size) { context, rect in
            drawSky(context, rect: rect, hue: hue)
            drawSunGlow(context, rect: rect, hue: hue, at: CGPoint(x: rect.width * 0.72, y: rect.height * 0.26))
            drawHaze(context, rect: rect, hue: hue)
            drawVignette(context, rect: rect)
        }
    }

    /// ホームのヒーロー用。ブランド色(ネイビー〜セージ)に寄せた1枚。
    static func homeHeroPhoto(size: CGSize = CGSize(width: 1_400, height: 1_800)) -> Data? {
        render(size: size) { context, rect in
            drawSky(context, rect: rect, hue: 0.53, saturation: 0.42)
            drawSunGlow(context, rect: rect, hue: 0.09, at: CGPoint(x: rect.width * 0.76, y: rect.height * 0.18))
            drawHaze(context, rect: rect, hue: 0.42)
            drawVignette(context, rect: rect)
        }
    }

    // MARK: - Layers

    /// 上が明るく下へ沈む、空から地面への縦グラデーション。
    private static func drawSky(_ context: CGContext, rect: CGRect, hue: CGFloat, saturation: CGFloat = 0.5) {
        let top = UIColor(hue: hue, saturation: saturation * 0.7, brightness: 0.68, alpha: 1)
        let mid = UIColor(hue: wrap(hue + 0.04), saturation: saturation, brightness: 0.4, alpha: 1)
        let bottom = UIColor(hue: wrap(hue + 0.08), saturation: saturation * 1.1, brightness: 0.16, alpha: 1)
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [top.cgColor, mid.cgColor, bottom.cgColor] as CFArray,
            locations: [0, 0.55, 1]
        ) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: 0),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
    }

    /// 太陽のにじみ。中心から外へ向けて透明に抜けるので、輪郭のない光になる。
    private static func drawSunGlow(_ context: CGContext, rect: CGRect, hue: CGFloat, at center: CGPoint) {
        let core = UIColor(hue: hue, saturation: 0.3, brightness: 1, alpha: 0.85)
        let edge = UIColor(hue: hue, saturation: 0.5, brightness: 0.9, alpha: 0)
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [core.cgColor, edge.cgColor] as CFArray,
            locations: [0, 1]
        ) else { return }
        context.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: min(rect.width, rect.height) * 0.55,
            options: []
        )
    }

    /// 地平線あたりに薄い霞をかけて、遠近感を出す。
    private static func drawHaze(_ context: CGContext, rect: CGRect, hue: CGFloat) {
        let clear = UIColor(hue: hue, saturation: 0.3, brightness: 0.9, alpha: 0)
        let haze = UIColor(hue: hue, saturation: 0.25, brightness: 0.85, alpha: 0.22)
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [clear.cgColor, haze.cgColor, clear.cgColor] as CFArray,
            locations: [0, 0.5, 1]
        ) else { return }
        let band = CGRect(x: 0, y: rect.height * 0.42, width: rect.width, height: rect.height * 0.3)
        context.saveGState()
        context.clip(to: band)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: band.minY),
            end: CGPoint(x: rect.midX, y: band.maxY),
            options: []
        )
        context.restoreGState()
    }

    /// 四隅を落として写真らしい締まりを出す。
    private static func drawVignette(_ context: CGContext, rect: CGRect) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [UIColor.black.withAlphaComponent(0).cgColor,
                     UIColor.black.withAlphaComponent(0.38).cgColor] as CFArray,
            locations: [0.55, 1]
        ) else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: max(rect.width, rect.height) * 0.72,
            options: []
        )
    }

    // MARK: - Helpers

    private static func wrap(_ hue: CGFloat) -> CGFloat { hue.truncatingRemainder(dividingBy: 1) }

    private static func render(size: CGSize, draw: (CGContext, CGRect) -> Void) -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // 端末の解像度倍率で水増ししない
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            draw(context.cgContext, CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.82)
    }
}

import SwiftUI

/// ホーム画面の写真は画面いっぱい(フルスクリーン)に表示される。編集プレビューの
/// 縦横比がそれと違うと、編集画面でちょうど良く見えてもホームでは全然違う場所が
/// 切り取られてしまう。編集用のプレビューはすべてこの比率(高さ/幅)に合わせる。
let homeHeroScreenAspectRatio: CGFloat = {
    let bounds = UIScreen.main.bounds
    guard bounds.width > 0 else { return 16.0 / 7.0 }
    return bounds.height / bounds.width
}()

/// 画面の縦横比のまま、指定の最大幅・最大高さに収まる編集プレビューのサイズを計算する。
/// 比率を保ったまま画面いっぱいの高さまで伸ばすと編集画面を占領してしまうため、
/// 見た目の精度(比率の正しさ)は保ちつつ、実際の表示サイズは程よく収める。
func homeHeroPreviewSize(maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
    let widthFromHeight = maxHeight / homeHeroScreenAspectRatio
    let width = min(maxWidth, widthFromHeight)
    return CGSize(width: width, height: width * homeHeroScreenAspectRatio)
}

struct HomeHeroCropView: View {
    let profile: UserProfile
    var isInteractive = false

    @State private var dragStartX: Double?
    @State private var dragStartY: Double?
    @State private var magnificationStart: Double?

    var body: some View {
        GeometryReader { proxy in
            if let data = profile.homeHeroPhotoData, let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 {
                let scale = max(profile.homeHeroScale, 1)
                // scaledToFill後の実際の描画サイズから、はみ出す量(overflow)を正しく計算する。
                // 以前は`コンテナ幅 * max(scale-1, 0.35)`という大雑把な近似値を使っていたが、
                // これは写真の縦横比とコンテナの縦横比の関係を無視しているため、実際のはみ出し量
                // より大きい/小さいことがあった。特にscale=1(拡大なし)であっても縦横比の差で
                // 生まれる実際のはみ出し量とズレるため、位置をドラッグで端に寄せると
                // 実際にカバーしている範囲を超えて動かせてしまい、写真の外側(隙間)が
                // 見えてしまうバグの原因になっていた。
                let fillScale = max(proxy.size.width / image.size.width, proxy.size.height / image.size.height)
                let renderedWidth = image.size.width * fillScale * scale
                let renderedHeight = image.size.height * fillScale * scale
                let overflowX = max(renderedWidth - proxy.size.width, 0)
                let overflowY = max(renderedHeight - proxy.size.height, 0)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(scale)
                    .offset(
                        x: (0.5 - profile.homeHeroFocalX) * overflowX,
                        y: (0.5 - profile.homeHeroFocalY) * overflowY
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(dragGesture(size: proxy.size))
                    .simultaneousGesture(magnifyGesture)
                    .allowsHitTesting(isInteractive)
                    .accessibilityLabel("ホーム写真の切り抜きプレビュー")
            } else {
                PhotoPlaceholderView(symbol: "photo", title: "写真がありません")
            }
        }
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartX == nil {
                    dragStartX = profile.homeHeroFocalX
                    dragStartY = profile.homeHeroFocalY
                }
                let sensitivity = max(profile.homeHeroScale, 1) * 1.5
                profile.homeHeroFocalX = min(max((dragStartX ?? 0.5) - Double(value.translation.width / size.width) / sensitivity, 0), 1)
                profile.homeHeroFocalY = min(max((dragStartY ?? 0.5) - Double(value.translation.height / size.height) / sensitivity, 0), 1)
            }
            .onEnded { _ in
                dragStartX = nil
                dragStartY = nil
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnificationStart == nil { magnificationStart = profile.homeHeroScale }
                profile.homeHeroScale = min(max((magnificationStart ?? 1) * value.magnification, 1), 3)
            }
            .onEnded { _ in magnificationStart = nil }
    }
}

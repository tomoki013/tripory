import SwiftUI

extension View {
    /// 小物パーツ(丸ボタン・バッジ等)向けのLiquid Glass適用。
    /// iOS 26未満ではmaterialベースの見た目にフォールバックする。
    /// 「透明度を減らす」設定が有効なときは、opaqueFallback(指定がなければtintかmaterial相当の不透明色)を敷く。
    @ViewBuilder
    func triporyGlass<S: Shape>(in shape: S, tint: Color? = nil, opaqueFallback: Color? = nil) -> some View {
        TriporyGlassContainer(tint: tint, opaqueFallback: opaqueFallback, shape: shape) { self }
    }
}

private struct TriporyGlassContainer<S: Shape, Content: View>: View {
    let tint: Color?
    let opaqueFallback: Color?
    let shape: S
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            content().background(opaqueFallback ?? tint ?? Color.triporyCanvas, in: shape)
        } else {
            content().glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: shape)
        }
    }
}

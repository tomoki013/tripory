import SwiftUI

/// アプリアイコンの縮小版。Assets.xcassetsの"TriporyIcon"(AppIcon.appiconsetと同じ絵柄の
/// 通常Imageset)を、実際のホーム画面アイコンと同じ角丸(スーパーエリプス)で切り抜いて使う。
/// AppIcon.appiconset自体はImage(_:)から直接参照できないため、表示用に複製している。
struct AppIconThumbnail: View {
    var size: CGFloat = 36

    var body: some View {
        Image("TriporyIcon")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// 「TRIPORY」の文字だけのワードマーク。VoiceOverでは常に「Tripory」と一語で読み上げる。
/// 大きなブランド表示・小さな見出しのどちらでも、常にこの文字ロゴを使う。
struct TriporyWordmark: View {
    var font: Font = .caption.weight(.bold)
    var tracking: CGFloat = 3
    var color: Color = .triporyGold

    var body: some View {
        Text(verbatim: "TRIPORY")
            .font(font)
            .triporyTracking(tracking)
            .foregroundStyle(color)
            .accessibilityLabel(Text(verbatim: "Tripory"))
    }
}

/// 4方向の頂点を持ち、輪郭が中心へ深く凹んだ「きらめき」の形。
/// SF Symbolの"sparkle"はやや絵文字的で安っぽく見えるため、自前のPathで描く。
private struct TwinkleShape: Shape {
    /// 頂点間の輪郭を中心へどれだけ引き込むか(1に近いほど細く鋭い形になる)。
    var pinch: CGFloat = 0.78

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let top = CGPoint(x: center.x, y: rect.minY)
        let right = CGPoint(x: rect.maxX, y: center.y)
        let bottom = CGPoint(x: center.x, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: center.y)

        func pulledControl(_ edgeMidpoint: CGPoint) -> CGPoint {
            CGPoint(
                x: edgeMidpoint.x + (center.x - edgeMidpoint.x) * pinch,
                y: edgeMidpoint.y + (center.y - edgeMidpoint.y) * pinch
            )
        }

        var path = Path()
        path.move(to: top)
        path.addQuadCurve(to: right, control: pulledControl(CGPoint(x: (top.x + right.x) / 2, y: (top.y + right.y) / 2)))
        path.addQuadCurve(to: bottom, control: pulledControl(CGPoint(x: (right.x + bottom.x) / 2, y: (right.y + bottom.y) / 2)))
        path.addQuadCurve(to: left, control: pulledControl(CGPoint(x: (bottom.x + left.x) / 2, y: (bottom.y + left.y) / 2)))
        path.addQuadCurve(to: top, control: pulledControl(CGPoint(x: (left.x + top.x) / 2, y: (left.y + top.y) / 2)))
        path.closeSubpath()
        return path
    }
}

/// Goldの小さな静止きらめき。1画面あたり最大1〜2個、装飾用途のみに使う。
/// SF Symbolの"sparkle"の代わりに、グラデーション+淡いグローを添えた自前の形を使うことで、
/// 安っぽい絵文字的な見た目を避ける。
struct BrandSparkle: View {
    var size: CGFloat = 12
    var color: Color = .triporyGold

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color.triporyIvory, color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            TwinkleShape()
                .fill(color)
                .frame(width: size * 1.6, height: size * 1.6)
                .blur(radius: size * 0.5)
                .opacity(0.45)
            TwinkleShape()
                .fill(gradient)
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

/// Midnight基調の背景。任意でHorizon Blueの薄い上部グラデーションと、
/// 固定Seedの微細な星(再描画しても位置が変わらない)を重ねる。
/// 写真を持たないブランド没入画面(Launchなど)向け。
struct MidnightBrandBackground: View {
    var showsHorizonGlow = true
    var showsStars = true

    var body: some View {
        ZStack {
            Color.triporyMidnight

            if showsHorizonGlow {
                LinearGradient(
                    colors: [Color.triporyHorizonBlue.opacity(0.35), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }

            if showsStars {
                GeometryReader { proxy in
                    ForEach(Array(Self.starSeeds.enumerated()), id: \.offset) { _, seed in
                        Circle()
                            .fill(.white.opacity(seed.opacity))
                            .frame(width: seed.size, height: seed.size)
                            .position(x: seed.x * proxy.size.width, y: seed.y * proxy.size.height)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// NewCountriesRevealViewの星空と同じ固定Seed値。
    static let starSeeds: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: CGFloat)] = [
        (0.12, 0.08, 2.5, 0.8), (0.3, 0.16, 1.5, 0.5), (0.52, 0.07, 2, 0.65),
        (0.72, 0.2, 1.5, 0.45), (0.9, 0.32, 2, 0.6), (0.08, 0.3, 1.5, 0.5),
        (0.2, 0.46, 2, 0.4), (0.85, 0.52, 1.5, 0.55), (0.14, 0.68, 2, 0.5),
        (0.4, 0.78, 1.5, 0.4), (0.66, 0.7, 2.5, 0.55), (0.92, 0.82, 1.5, 0.45),
        (0.48, 0.3, 1.5, 0.35), (0.62, 0.44, 2, 0.5), (0.26, 0.88, 2, 0.5),
    ]
}

/// 地球+軌道+光点のロゴモチーフ。
/// 地球部分は実写・ベクター地図を使わず、放射グラデーションの円で簡易的に表現する
/// (正式なロゴAssetは別途用意する想定で、APIはそのまま画像版へ差し替えられる形にしてある)。
/// 軌道はCircleのtrim+strokeで描き、`orbitProgress`(0...1)で進捗と光点の位置を制御する。
struct TriporyOrbitMark: View {
    var size: CGFloat = 120
    var showsGlow: Bool = true
    var orbitProgress: Double = 1
    var accessibilityLabel: LocalizedStringKey?

    private var globeDiameter: CGFloat { size * 0.62 }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.triporyHorizonBlue.opacity(0.9), Color.triporyMidnight],
                        center: UnitPoint(x: 0.32, y: 0.3),
                        startRadius: 1,
                        endRadius: globeDiameter * 0.7
                    )
                )
                .frame(width: globeDiameter, height: globeDiameter)
                .overlay {
                    if showsGlow {
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: globeDiameter * 0.22, height: globeDiameter * 0.22)
                            .blur(radius: globeDiameter * 0.08)
                            .offset(x: -globeDiameter * 0.18, y: -globeDiameter * 0.2)
                    }
                }

            Circle()
                .trim(from: 0, to: max(0, min(orbitProgress, 1)))
                .stroke(Color.triporyGold, style: StrokeStyle(lineWidth: max(1, size * 0.012), lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            if orbitProgress > 0 {
                Circle()
                    .fill(Color.triporyGold)
                    .frame(width: size * 0.045, height: size * 0.045)
                    .shadow(color: showsGlow ? Color.triporyGold.opacity(0.8) : .clear, radius: size * 0.02)
                    .position(orbitPoint(at: orbitProgress, diameter: size))
            }
        }
        .frame(width: size, height: size)
        .modifier(OrbitMarkAccessibility(label: accessibilityLabel))
    }

    private func orbitPoint(at progress: Double, diameter: CGFloat) -> CGPoint {
        let angle = Angle.degrees(-90 + 360 * max(0, min(progress, 1)))
        let radius = diameter / 2
        return CGPoint(x: radius + radius * cos(angle.radians), y: radius + radius * sin(angle.radians))
    }
}

private struct OrbitMarkAccessibility: ViewModifier {
    let label: LocalizedStringKey?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityElement(children: .ignore).accessibilityLabel(label)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

import SwiftUI

/// Midnight Atlas: ブランドロゴ(TriporyOrbitMark)のGold軌道が描き終わり、
/// ロゴが浮かび上がる起動アニメーション。
struct LaunchAnimationView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let orbitDuration: Double = 0.55

    @State private var globeOpacity: Double = 0
    @State private var orbitProgress: Double = 0
    @State private var pulseScale: CGFloat = 1
    @State private var pulseOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 8
    @State private var viewOpacity: Double = 1

    var body: some View {
        ZStack {
            MidnightBrandBackground(showsHorizonGlow: true, showsStars: true)

            VStack(spacing: 28) {
                TriporyOrbitMark(size: 140, showsGlow: true, orbitProgress: orbitProgress)
                    .overlay {
                        Circle()
                            .stroke(Color.triporyGold.opacity(pulseOpacity), lineWidth: 2)
                            .scaleEffect(pulseScale)
                    }
                    .opacity(globeOpacity)

                VStack(spacing: 10) {
                    TriporyWordmark(font: .caption.weight(.bold), tracking: 4, color: .triporyGold)
                    Text("あなたの旅の記録")
                        .font(TriporyTypography.brandTitle(26))
                        .foregroundStyle(Color.triporyIvory)
                    Text("これまでの旅を、世界地図に。")
                        .font(.subheadline)
                        .foregroundStyle(Color.triporySecondaryText)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
            }
        }
        .opacity(viewOpacity)
        .onAppear { start() }
    }

    private func start() {
        if reduceMotion {
            // Reduce Motion時は軌道描画・パルスを省略し、ロゴを短くFadeするだけにする。
            withAnimation(.easeOut(duration: 0.35)) {
                globeOpacity = 1
                titleOpacity = 1
                titleOffset = 0
            }
            orbitProgress = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                finish()
            }
            return
        }

        withAnimation(.easeOut(duration: 0.3)) {
            globeOpacity = 1
        }
        withAnimation(.easeInOut(duration: orbitDuration).delay(0.1)) {
            orbitProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + orbitDuration) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                pulseOpacity = 0.7
                pulseScale = 1
            }
            withAnimation(.easeOut(duration: 0.45)) {
                pulseScale = 1.35
                pulseOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.35)) {
                titleOpacity = 1
                titleOffset = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                finish()
            }
        }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onFinished()
        }
    }
}

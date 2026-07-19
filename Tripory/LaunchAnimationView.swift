import SwiftUI

/// 出発点から目的地へ、軌跡を描きながら飛行機が飛ぶ起動アニメーション。
private enum FlightCurve {
    static let start = CGPoint(x: 36, y: 168)
    static let end = CGPoint(x: 264, y: 50)
    static let control1 = CGPoint(x: 130, y: 168)
    static let control2 = CGPoint(x: 192, y: 66)

    static var path: Path {
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }

    static func point(at t: Double) -> CGPoint {
        let mt = 1 - t
        let x = mt*mt*mt*start.x + 3*mt*mt*t*control1.x + 3*mt*t*t*control2.x + t*t*t*end.x
        let y = mt*mt*mt*start.y + 3*mt*mt*t*control1.y + 3*mt*t*t*control2.y + t*t*t*end.y
        return CGPoint(x: x, y: y)
    }

    static func angle(at t: Double) -> Angle {
        let mt = 1 - t
        let dx = 3*mt*mt*(control1.x - start.x) + 6*mt*t*(control2.x - control1.x) + 3*t*t*(end.x - control2.x)
        let dy = 3*mt*mt*(control1.y - start.y) + 6*mt*t*(control2.y - control1.y) + 3*t*t*(end.y - control2.y)
        return Angle(radians: atan2(dy, dx))
    }

    static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
}

struct LaunchAnimationView: View {
    var onFinished: () -> Void

    private let flightDuration: Double = 1.3

    @State private var flightStartedAt: Date?
    @State private var flightFinished = false
    @State private var planeOpacity: Double = 1
    @State private var endDotScale: CGFloat = 0.01
    @State private var pulseScale: CGFloat = 1
    @State private var pulseOpacity: Double = 0.6
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 8
    @State private var viewOpacity: Double = 1

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                TimelineView(.animation(paused: flightFinished)) { context in
                    let t = progress(at: context.date)
                    ZStack {
                        FlightCurve.path
                            .trim(from: 0, to: t)
                            .stroke(
                                LinearGradient(
                                    colors: [.gray.opacity(0.35), .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )

                        Circle()
                            .fill(Color.gray.opacity(0.45))
                            .frame(width: 7, height: 7)
                            .position(FlightCurve.start)

                        Circle()
                            .stroke(Color.orange.opacity(pulseOpacity), lineWidth: 2)
                            .frame(width: 22, height: 22)
                            .scaleEffect(pulseScale)
                            .position(FlightCurve.end)

                        Circle()
                            .fill(Color.orange)
                            .frame(width: 9, height: 9)
                            .scaleEffect(endDotScale)
                            .position(FlightCurve.end)

                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.75))
                            .rotationEffect(FlightCurve.angle(at: t) + .degrees(45))
                            .position(FlightCurve.point(at: t))
                            .opacity(planeOpacity)
                    }
                    .onChange(of: t) { _, newValue in
                        if newValue >= 1, !flightFinished {
                            flightFinished = true
                            handleFlightFinished()
                        }
                    }
                }
                .frame(width: 300, height: 200)

                VStack(spacing: 10) {
                    Text(verbatim: "TRIPORY")
                        .font(.caption)
                        .tracking(4)
                        .foregroundStyle(.secondary)
                    Text("あなたの旅の記録")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                    Text("これまでの旅を、世界地図に。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
            }
        }
        .opacity(viewOpacity)
        .onAppear { flightStartedAt = Date() }
    }

    private func progress(at date: Date) -> Double {
        guard let flightStartedAt else { return 0 }
        let elapsed = date.timeIntervalSince(flightStartedAt)
        let raw = min(elapsed / flightDuration, 1)
        return FlightCurve.easeInOut(raw)
    }

    private func handleFlightFinished() {
        withAnimation(.easeOut(duration: 0.3)) {
            planeOpacity = 0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            endDotScale = 1
        }
        withAnimation(.easeOut(duration: 0.9)) {
            pulseScale = 2.4
            pulseOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            titleOpacity = 1
            titleOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.4)) {
                viewOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onFinished()
            }
        }
    }
}

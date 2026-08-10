import SwiftUI
import MapKit

struct OnboardingWelcomeStep: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                HStack {
                    OnboardingProgress(step: .welcome)
                    Spacer()
                    TriporyWordmark(font: .caption2.weight(.bold), tracking: 3, color: .triporyGold)
                }
                .padding(.top, 62)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                VStack(spacing: 16) {
                    Text("Your world, beautifully mapped.")
                        .font(TriporyTypography.brandTitle(34))
                        .foregroundStyle(.white)
                    Text("旅を記録するたび、\n訪れた国と思い出が、\nあなたの世界になっていく。")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineSpacing(6)
                }
                .offset(y: isVisible ? 0 : 12)
                .opacity(isVisible ? 1 : 0)

                Spacer()

                PrimaryCapsuleButton(title: "はじめる", style: .ivory, action: onContinue)
                    .padding(.bottom, 34)
                    .opacity(isVisible ? 1 : 0)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
        }
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.1)) {
                    isVisible = true
                }
            }
        }
    }

    /// 差し替え用の実写真(Assets.xcassetsの"OnboardingWelcomePhoto")を画面全体に敷き、
    /// なければ従来の幾何学グラデーションへフォールバックする(どちらも文字は白で読める濃さ)。
    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            if let uiImage = UIImage(named: "OnboardingWelcomePhoto") {
                GeometryReader { proxy in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            } else {
                LinearGradient(
                    colors: [Color.triporyNavy, Color.triporySage.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.42), location: 0),
                    .init(color: .black.opacity(0.2), location: 0.28),
                    .init(color: .black.opacity(0.5), location: 0.62),
                    .init(color: .black.opacity(0.82), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct OnboardingGlobePreview: UIViewRepresentable {
    let centerCode: String
    var interactive = true

    final class PreviewMapView: MKMapView {
        var initialCamera: MKMapCamera?
        private var didPosition = false

        override func layoutSubviews() {
            super.layoutSubviews()
            guard !didPosition, bounds.width > 0, let initialCamera else { return }
            didPosition = true
            setCamera(initialCamera, animated: false)
        }
    }

    func makeUIView(context: Context) -> PreviewMapView {
        let map = PreviewMapView()
        let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
        configuration.emphasisStyle = .muted
        map.preferredConfiguration = configuration
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.showsScale = false
        map.isUserInteractionEnabled = interactive
        map.isRotateEnabled = interactive
        map.isPitchEnabled = interactive
        map.isScrollEnabled = interactive
        map.isZoomEnabled = interactive
        let center = CountryCoordinates.coordinate(for: centerCode)
            ?? CLLocationCoordinate2D(latitude: 20, longitude: 20)
        map.initialCamera = MKMapCamera(lookingAtCenter: center, fromDistance: 48_000_000, pitch: 0, heading: 0)
        return map
    }

    func updateUIView(_ map: PreviewMapView, context: Context) {}
}

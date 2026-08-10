import SwiftUI

/// 新しく加わった1か国分。旅の写真があればそれを、なければホーム写真を背景に使う。
struct NewCountryReveal: Identifiable {
    let country: Country
    let coverPhotoData: Data?
    var id: String { country.code }
}

struct NewCountriesRevealPayload: Identifiable {
    let id = UUID()
    let countries: [NewCountryReveal]
    let totalCount: Int
}

/// 旅の保存によって初めて加わった国だけを、暗い星空の上で1か国ずつ祝う演出。
/// 国に紐づく写真があればその写真、無ければホーム写真を背景に前面表示する。
struct NewCountriesRevealView: View {
    let payload: NewCountriesRevealPayload
    var homePhotoData: Data? = nil
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var isVisible = false

    private var currentReveal: NewCountryReveal { payload.countries[index] }
    private var country: Country { currentReveal.country }
    private var isLast: Bool { index == payload.countries.count - 1 }
    private var backgroundPhotoData: Data? { currentReveal.coverPhotoData ?? homePhotoData }

    var body: some View {
        ZStack {
            Color.triporyNavy.ignoresSafeArea()
            backgroundPhoto
            starField

            VStack(spacing: 0) {
                if payload.countries.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(payload.countries.indices, id: \.self) { step in
                            Capsule()
                                .fill(step <= index ? Color.triporyCoral : Color.triporyIvory.opacity(0.2))
                                .frame(height: 5)
                        }
                    }
                    .padding(.top, 18)
                }

                Spacer()

                VStack(spacing: 20) {
                    Text("新しい国")
                        .font(.subheadline.weight(.black))
                        .tracking(4)
                        .foregroundStyle(Color.triporyGold)

                    ZStack {
                        // 国旗の背後に、Goldの軌道リングを1本だけごく薄く重ねる。
                        TriporyOrbitMark(size: 150, showsGlow: false, orbitProgress: 1)
                            .opacity(0.22)
                        Text(country.flag)
                            .font(.system(size: 92))
                            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                    }
                    .scaleEffect(isVisible ? 1 : 0.7)
                    .opacity(isVisible ? 1 : 0)

                    VStack(spacing: 12) {
                        Text(country.name)
                            .font(.system(size: 46, weight: .semibold, design: .serif))
                        Text(isLast
                            ? String(format: String(localized: "あなたの世界は%lldか国になりました！"), payload.totalCount)
                            : String(localized: "あなたの世界に、新しい国が加わりました。"))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .offset(y: isVisible ? 0 : 14)
                    .opacity(isVisible ? 1 : 0)
                }

                Spacer()

                Button(action: advance) {
                    Text(isLast ? "My Worldを見る" : "次の国へ")
                        .font(.headline)
                        .foregroundStyle(Color.triporyNavy)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .onAppear { reveal() }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var backgroundPhoto: some View {
        if let backgroundPhotoData, let image = UIImage(data: backgroundPhotoData) {
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            .overlay {
                LinearGradient(
                    colors: [Color.triporyNavy.opacity(0.55), Color.triporyNavy.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .transition(.opacity)
            .id(currentReveal.id)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// 位置固定の小さな星と、ひとつの金色の光でモックの夜空をつくる。
    /// 金色の光は「写真がない場合の夜空の代役」としての演出なので、実際の写真が
    /// 表示されているときに重ねると、右上に謎の光る円が浮いて見えるだけになる。
    /// 写真がある間は星も光も出さない。
    private var starField: some View {
        GeometryReader { proxy in
            if backgroundPhotoData == nil {
                ZStack {
                    ForEach(Array(Self.starSeeds.enumerated()), id: \.offset) { _, seed in
                        Circle()
                            .fill(.white.opacity(seed.opacity))
                            .frame(width: seed.size, height: seed.size)
                            .position(
                                x: seed.x * proxy.size.width,
                                y: seed.y * proxy.size.height
                            )
                    }
                    Circle()
                        .fill(Color.triporyGold.opacity(0.85))
                        .frame(width: 150, height: 150)
                        .blur(radius: 2)
                        .position(x: proxy.size.width * 0.86, y: proxy.size.height * 0.1)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private static let starSeeds: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: CGFloat)] = [
        (0.12, 0.08, 2.5, 0.8), (0.3, 0.16, 1.5, 0.5), (0.52, 0.07, 2, 0.65),
        (0.72, 0.2, 1.5, 0.45), (0.9, 0.32, 2, 0.6), (0.08, 0.3, 1.5, 0.5),
        (0.2, 0.46, 2, 0.4), (0.85, 0.52, 1.5, 0.55), (0.14, 0.68, 2, 0.5),
        (0.4, 0.78, 1.5, 0.4), (0.66, 0.7, 2.5, 0.55), (0.92, 0.82, 1.5, 0.45),
        (0.48, 0.3, 1.5, 0.35), (0.62, 0.44, 2, 0.5), (0.26, 0.88, 2, 0.5),
    ]

    private func advance() {
        guard !isLast else {
            onFinish()
            return
        }

        if reduceMotion {
            index += 1
            isVisible = true
        } else {
            withAnimation(.easeIn(duration: 0.16)) { isVisible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
                index += 1
                reveal()
            }
        }
    }

    private func reveal() {
        guard !payload.countries.isEmpty else {
            onFinish()
            return
        }
        if reduceMotion {
            isVisible = true
        } else {
            isVisible = false
            withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
                isVisible = true
            }
        }
    }
}

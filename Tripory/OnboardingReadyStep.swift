import SwiftUI

/// 最終ステップ = 上半分に選んだ写真をフルブリードで敷いて「My World」を予告し、
/// 下半分はクリーム地に円形の3D地球とCTAを置く。
struct OnboardingReadyStep: View {
    let profile: UserProfile
    let homeCountryCode: String
    let countryCount: Int
    let onOpen: () -> Void

    private var homeCountryName: String {
        CountryCatalog.byCode[homeCountryCode]?.name ?? homeCountryCode
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                heroSection
                    .frame(height: proxy.size.height * 0.56)
                bottomSection
                    .frame(maxHeight: .infinity)
            }
            .background(Color.triporyCanvas)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            HomeHeroCropView(profile: profile)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.5), location: 0),
                    .init(color: .black.opacity(0.1), location: 0.4),
                    .init(color: Color.triporyNavy.opacity(0.85), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                OnboardingProgress(step: .ready)
                    .padding(.top, 62)

                Text("マイワールド")
                    .font(.system(size: 42, design: .serif))
                    .padding(.top, 26)
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("\(countryCount)")
                        .font(.system(size: 52, design: .serif).monospacedDigit())
                    Text("か国")
                        .font(.caption.weight(.bold))
                        .tracking(1.6)
                }

                Spacer()

                Text(String(format: String(localized: "%@から始まる、あなたの世界。"), homeCountryName))
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .lineSpacing(4)
                    .padding(.bottom, 26)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
        }
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("あなたの世界の準備ができました。My World、\(countryCount)か国。")
    }

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)

            ZStack {
                Circle()
                    .fill(Color.triporyGold.opacity(0.14))
                    .frame(width: 190, height: 190)
                    .blur(radius: 6)
                OnboardingGlobePreview(centerCode: homeCountryCode, interactive: false)
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.triporyNavy.opacity(0.15), lineWidth: 1))
                    .shadow(color: Color.triporyNavy.opacity(0.25), radius: 20, y: 10)
            }
            .accessibilityHidden(true)

            Text(String(format: String(localized: "3D地球は%@を中心に開きます"), homeCountryName))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            Spacer(minLength: 22)

            PrimaryCapsuleButton(title: "Triporyを開く", action: onOpen)
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
        }
    }
}

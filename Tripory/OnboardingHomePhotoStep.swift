import SwiftUI
import PhotosUI

struct OnboardingHomePhotoStep: View {
    let profile: UserProfile
    let onContinue: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var cropPreviewSize: CGSize {
        homeHeroPreviewSize(maxWidth: UIScreen.main.bounds.width - 48, maxHeight: 380)
    }

    var body: some View {
        ZStack {
            Color.triporyNavy
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingProgress(step: .homePhoto)
                        .padding(.top, 62)

                    Text("あなたの世界を\n表す一枚")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 34)
                    Text("この写真がホームの主役になります。後からいつでも変更できます。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineSpacing(4)
                        .padding(.top, 10)

                    // ホームでは画面いっぱいに表示されるため、編集プレビューもその縦横比に
                    // 合わせる。ここで正方形に近い比率のまま良い位置に合わせても、
                    // 実際のホームでは全然違う場所が切り取られてしまうのを防ぐ。
                    // 「ホームでの見え方」を別の小さなモックとして横に並べていたが、
                    // ドラッグ対象そのものに同じオーバーレイを重ねれば、動かしながら
                    // 直接その見え方を確認できるので二重に表示する必要がない。
                    Group {
                        if profile.homeHeroPhotoData != nil {
                            HomeHeroCropView(profile: profile, isInteractive: true)
                                .overlay(alignment: .bottom) { heroPreviewOverlay }
                        } else {
                            PhotoPlaceholderView(symbol: "photo.badge.plus", title: "あなたらしい旅の写真を選ぶ")
                        }
                    }
                    .frame(width: cropPreviewSize.width, height: cropPreviewSize.height)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.7), lineWidth: 1.5))
                    .padding(.top, 28)

                    if profile.homeHeroPhotoData != nil {
                        Text("ドラッグして位置を調整。ホームでの見え方がそのままプレビューされます。")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.triporyGold)
                            .padding(.top, 14)
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text(profile.homeHeroPhotoData == nil ? "写真を選ぶ" : "写真を選び直す")
                            .font(.headline)
                            .foregroundStyle(Color.triporyNavy)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .overlay {
                        if isLoading { ProgressView().tint(Color.triporyNavy) }
                    }
                    .padding(.top, 24)

                    PrimaryCapsuleButton(
                        title: "この写真にする",
                        style: .coral,
                        isEnabled: profile.homeHeroPhotoData != nil && !isLoading,
                        action: onContinue
                    )
                    .padding(.top, 12)
                    .padding(.bottom, 34)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: pickerItem) { _, item in
            Task { await load(item) }
        }
    }

    @MainActor
    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let compressed = ImageCompression.compress(data)
            else {
                errorMessage = String(localized: "写真を読み込めませんでした。別の写真を選んでください。")
                return
            }
            profile.homeHeroPhotoData = compressed
            profile.homeHeroFocalX = 0.5
            profile.homeHeroFocalY = 0.5
            profile.homeHeroScale = 1
            try? modelContext.save()
        } catch {
            errorMessage = String(localized: "写真を読み込めませんでした。もう一度お試しください。")
        }
    }

    /// ドラッグ中の写真の上に、実際のホーム画面と同じグラデーション+「My World」表記を
    /// 重ねる。ドラッグ対象自身がそのままプレビューになるので、別枠のモック表示は不要。
    private var heroPreviewOverlay: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.5), location: 0),
                    .init(color: .black.opacity(0.1), location: 0.34),
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.6), location: 0.86),
                    .init(color: .black.opacity(0.78), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "My World")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                Text(verbatim: "6")
                    .font(.system(size: 32, design: .serif))
                    .padding(.top, 4)
                Text(verbatim: "COUNTRIES")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .opacity(0.85)
            }
            .padding(16)
            .foregroundStyle(.white)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

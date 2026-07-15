import SwiftUI
import SwiftData

/// 初回起動時に住んでいる国を選んでもらう画面。
/// 選んだ国は「訪問済み」として登録される(海外旅行の記録から除外するための基準にもなる)。
struct OnboardingView: View {
    let onComplete: (Country) -> Void

    @State private var confirmingCountry: Country?
    @State private var showingPicker = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 14) {
                Text("TRIPORY")
                    .font(.caption.bold())
                    .tracking(3)
                    .foregroundStyle(.teal)
                Text("はじめに、住んでいる国を\n教えてください")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                Text("海外旅行の記録から、住んでいる国を除くために使います。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    showingPicker = true
                } label: {
                    Text("国を選ぶ")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.top, 12)
            }
        }
        .sheet(isPresented: $showingPicker) {
            CountryPickerView { country in
                confirmingCountry = country
            }
            .interactiveDismissDisabled()
        }
        .sheet(item: $confirmingCountry) { country in
            ConfirmHomeCountryView(
                country: country,
                onConfirm: { onComplete(country) },
                onReselect: {
                    confirmingCountry = nil
                    showingPicker = true
                }
            )
            .interactiveDismissDisabled()
        }
    }
}

/// 「間違えた」を防ぐための確認ステップ。オンボーディングと設定変更の両方から使う。
struct ConfirmHomeCountryView: View {
    let country: Country
    let onConfirm: () -> Void
    let onReselect: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                Text(country.flag)
                    .font(.system(size: 84))
                Text(country.name)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                Text("この国でよろしいですか?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()

                Button(action: onConfirm) {
                    Text("はい、これにする")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                Button("国を選び直す", action: onReselect)
                    .fontWeight(.semibold)
            }
            .padding(32)
        }
    }
}

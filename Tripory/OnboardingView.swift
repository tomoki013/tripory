import SwiftUI

/// 「間違えた」を防ぐための確認ステップ。オンボーディングと設定変更の両方から使う。
struct ConfirmHomeCountryView: View {
    let country: Country
    let onConfirm: () -> Void
    let onReselect: () -> Void

    var body: some View {
        ZStack {
            Color.triporyCanvas.ignoresSafeArea()

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
                            Color.triporyNavy,
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

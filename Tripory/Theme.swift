import SwiftUI
import UIKit

extension Color {
    static let triporyCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.075, blue: 0.09, alpha: 1)
            : UIColor(red: 0.961, green: 0.941, blue: 0.91, alpha: 1)
    })

    static let triporyInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1)
            : UIColor(red: 0.106, green: 0.122, blue: 0.149, alpha: 1)
    })

    static let triporyNavy = Color(red: 0.059, green: 0.122, blue: 0.18)
    static let triporyCoral = Color(red: 0.878, green: 0.404, blue: 0.286)
    static let triporyGold = Color(red: 0.824, green: 0.612, blue: 0.329)
    static let triporySage = Color(red: 0.447, green: 0.561, blue: 0.525)
    static let triporyRust = Color(red: 0.722, green: 0.4, blue: 0.341)
    static let triporyBlue = Color(red: 0.322, green: 0.498, blue: 0.569)

    static let triporyCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.102, green: 0.137, blue: 0.16, alpha: 1)
            : UIColor(red: 0.99, green: 0.985, blue: 0.972, alpha: 1)
    })

    // 既存画面を段階的に更新する間の互換名。
    static let appBackground = triporyCanvas
    static let appCard = triporyCard
}

/// 写真やマップの上に重ねる円形ガラスアイコンボタン。
/// アイコンを固定サイズの箱に収めることで、記号ごとの固有幅(chevron=細い/ellipsis=広い)に
/// 左右されず、全画面で必ず同じ大きさの円になる。
struct CircleGlassButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var tint: Color = .white
    var size: ControlSize = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TriporyCircleGlassIcon(systemImage: systemImage)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(size)
        .tint(tint)
        .accessibilityLabel(Text(label))
    }
}

/// 同じ見た目の円形ガラスボタンで、タップするとメニューを開くもの(⋯ など)。
struct CircleGlassMenu<Content: View>: View {
    let systemImage: String
    let label: LocalizedStringKey
    var tint: Color = .white
    var size: ControlSize = .regular
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            TriporyCircleGlassIcon(systemImage: systemImage)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(size)
        .tint(tint)
        .accessibilityLabel(Text(label))
    }
}

/// 円形ガラスボタン共通のアイコン。24×24の正方形に固定してサイズを均一化する。
struct TriporyCircleGlassIcon: View {
    let systemImage: String
    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 24, height: 24)
    }
}

extension View {
    /// 翻訳される文字列に字間を効かせるときは必ずこれを使う。
    /// アラビア文字・ヘブライ文字は字が連結するため、素の `.tracking()` を当てると
    /// 単語がバラバラに分解して見える。該当言語では字間を0に落とす。
    func triporyTracking(_ value: CGFloat) -> some View {
        modifier(ScriptAwareTracking(value: value))
    }

    /// 装飾の水平オフセット。RTLでは左右を反転させる
    /// (`offset(x:)` は `padding(.leading)` などと違い自動では反転しない)。
    func triporyDecorativeOffset(x: CGFloat, y: CGFloat) -> some View {
        modifier(DirectionAwareOffset(x: x, y: y))
    }
}

private struct ScriptAwareTracking: ViewModifier {
    let value: CGFloat
    @Environment(\.locale) private var locale

    /// 字が連結する文字体系(アラビア文字系・ヘブライ文字)では字間調整を行わない。
    private var allowsTracking: Bool {
        guard let code = locale.language.languageCode?.identifier else { return true }
        return !["ar", "he", "fa", "ur"].contains(code)
    }

    func body(content: Content) -> some View {
        content.tracking(allowsTracking ? value : 0)
    }
}

private struct DirectionAwareOffset: ViewModifier {
    let x: CGFloat
    let y: CGFloat
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.offset(x: layoutDirection == .rightToLeft ? -x : x, y: y)
    }
}

enum PrimaryCapsuleButtonStyle {
    case navy
    case coral

    var color: Color {
        switch self {
        case .navy: return .triporyNavy
        case .coral: return .triporyCoral
        }
    }
}

struct PrimaryCapsuleButton: View {
    let title: String
    var style: PrimaryCapsuleButtonStyle = .navy
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(style.color.opacity(isEnabled ? 1 : 0.35), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(.isButton)
    }
}

struct EditorialTitle: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(.largeTitle, design: .serif, weight: .semibold))
            .foregroundStyle(Color.triporyInk)
    }
}

struct TriporySectionHeader: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.triporyInk)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.triporyCoral)
                }
            }
        }
    }
}

struct PhotoPlaceholderView: View {
    let symbol: String
    let title: LocalizedStringKey

    /// 「写真が未設定」の見せ方の既定値として、Assets.xcassetsの"OnboardingWelcomePhoto"を
    /// 使う。見つからない場合のみ、従来の幾何学グラデーションにフォールバックする。
    private var defaultPhoto: UIImage? { UIImage(named: "OnboardingWelcomePhoto") }

    var body: some View {
        ZStack {
            if let defaultPhoto {
                Image(uiImage: defaultPhoto)
                    .resizable()
                    .scaledToFill()
                LinearGradient(
                    colors: [Color.triporyNavy.opacity(0.35), Color.triporyNavy.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [Color.triporyNavy, Color.triporySage.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.triporyGold.opacity(0.9))
                    .frame(width: 92, height: 92)
                    .triporyDecorativeOffset(x: 88, y: -70)
            }
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .light))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding()
        }
        .clipped()
        .accessibilityElement(children: .combine)
    }
}

struct EmptyCollectionState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.triporySage)
            Text(title)
                .font(.system(.title2, design: .serif, weight: .semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle).fontWeight(.semibold) }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(.triporyCoral)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}

import SwiftUI
import UIKit

// MARK: - Midnight Atlas ブランドカラー
//
// ブランド実装指示書(TRIPORY_MIDNIGHT_ATLAS_IMPLEMENTATION.md)で確定した5色。
// Hexは指示書の値をそのまま使う: Midnight #0B1320 / Horizon Blue #2A3D5F /
// Warm Coral #E07A5F / Soft Ivory #F5EFE6 / Heritage Gold #C8A96B。
extension Color {
    // MARK: 物理カラートークン
    static let triporyMidnight = Color(red: 0x0B / 255, green: 0x13 / 255, blue: 0x20 / 255)
    static let triporyHorizonBlue = Color(red: 0x2A / 255, green: 0x3D / 255, blue: 0x5F / 255)
    static let triporyCoral = Color(red: 0xE0 / 255, green: 0x7A / 255, blue: 0x5F / 255)
    static let triporyIvory = Color(red: 0xF5 / 255, green: 0xEF / 255, blue: 0xE6 / 255)
    static let triporyGold = Color(red: 0xC8 / 255, green: 0xA9 / 255, blue: 0x6B / 255)

    // 互換エイリアス: 旧トークン名のまま使っている既存コードを壊さないための橋渡し。
    // triporySage/triporyBlueは装飾的なグラデーションに使われており、Horizon Blueへ
    // 統一する(CountryRelationship.livedだけは別途Goldを直接指定する)。
    static let triporyNavy = triporyMidnight
    static let triporySage = triporyHorizonBlue
    static let triporyBlue = triporyHorizonBlue
    static let triporyRust = Color(red: 0.722, green: 0.4, blue: 0.341)

    /// 訪問回数の段階(1回/2回/3回以上)をCoralファミリー内の別RGBで区別するための明るい版。
    /// 単なるopacity違いにすると、MKPolygonRendererがfillColorのalphaを
    /// withAlphaComponent()で強制上書きする関係で地球儀上ではすべて同じ色に潰れてしまう
    /// (実際に起きた不具合: 訪問回数に関わらず全部「3回以上訪問」の色に見える)。
    /// そのためalphaではなくRGBそのものを変えて区別する。
    static let triporyCoralLight = Color(red: 0xF2 / 255, green: 0xA7 / 255, blue: 0x8D / 255)

    // MARK: セマンティックトークン(Light/Darkに追従する実用画面向け)
    static let triporyCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x0B / 255, green: 0x13 / 255, blue: 0x20 / 255, alpha: 1)
            : UIColor(red: 0xF5 / 255, green: 0xEF / 255, blue: 0xE6 / 255, alpha: 1)
    })

    static let triporyInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xF5 / 255, green: 0xEF / 255, blue: 0xE6 / 255, alpha: 1)
            : UIColor(red: 0x0B / 255, green: 0x13 / 255, blue: 0x20 / 255, alpha: 1)
    })

    static let triporySecondaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xF5 / 255, green: 0xEF / 255, blue: 0xE6 / 255, alpha: 0.65)
            : UIColor(red: 0x0B / 255, green: 0x13 / 255, blue: 0x20 / 255, alpha: 0.6)
    })

    static let triporyDivider = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xF5 / 255, green: 0xEF / 255, blue: 0xE6 / 255, alpha: 0.12)
            : UIColor(red: 0x0B / 255, green: 0x13 / 255, blue: 0x20 / 255, alpha: 0.1)
    })

    static let triporyCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x11 / 255, green: 0x1D / 255, blue: 0x2D / 255, alpha: 1)
            : UIColor(red: 0.99, green: 0.985, blue: 0.972, alpha: 1)
    })

    static let triporyElevatedSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x16 / 255, green: 0x24 / 255, blue: 0x38 / 255, alpha: 1)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    })

    static let triporyGlassTint = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x0B / 255, green: 0x13 / 255, blue: 0x20 / 255, alpha: 0.55)
            : UIColor(red: 0x0B / 255, green: 0x13 / 255, blue: 0x20 / 255, alpha: 0.08)
    })

    /// 写真の上に重ねて可読性を確保するグラデーションの基調色。素の`.black`の代わりに使う。
    static let triporyPhotoOverlay = triporyMidnight

    // 既存画面を段階的に更新する間の互換名。
    static let appBackground = triporyCanvas
    static let appCard = triporyCard
}

// MARK: - タイポグラフィ
//
// Primary(ブランドSerif)は指示書ではCormorant Garamondだが、フォントファイルを
// バンドルしていないため、既存でも使っているSystem Serif(New York)をそのまま使う。
// 将来カスタムフォントを追加する場合は、ここの`design: .serif`をカスタムフォント指定に
// 差し替えるだけで全画面へ反映できるよう、フォントは必ずこのenum経由で参照する。
enum TriporyTypography {
    static func brandLargeTitle(_ size: CGFloat = 54) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func brandTitle(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func brandNumber(_ size: CGFloat = 60) -> Font {
        .system(size: size, weight: .regular, design: .serif).monospacedDigit()
    }

    static var sectionTitle: Font { .headline }
    static var body: Font { .subheadline }
    static var caption: Font { .caption.weight(.semibold) }
    static var eyebrow: Font { .caption.weight(.bold) }
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
    /// Midnight Atlas: 夜の写真の上に置く開始ボタン用。Soft Ivory背景+Midnight文字。
    case ivory

    var color: Color {
        switch self {
        case .navy: return .triporyNavy
        case .coral: return .triporyCoral
        case .ivory: return .triporyIvory
        }
    }

    var textColor: Color {
        self == .ivory ? .triporyMidnight : .white
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
                .foregroundStyle(style.textColor)
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

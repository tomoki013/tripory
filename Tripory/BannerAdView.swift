import GoogleMobileAds
import SwiftUI
import UIKit

struct RootBannerAd: View {
    let width: CGFloat

    @Environment(PurchaseManager.self) private var purchases
    @Environment(ConsentManager.self) private var consent
    @Environment(AdsService.self) private var ads
    @State private var loaded = false

    // 広告枠のSwiftUI上のframeと実際の広告ビューの高さが食い違うと、広告が枠から
    // はみ出して直下・直上のボタン(+ボタンやタブバー)のタップを奪ってしまう。
    // 必ずこのadSize.size.heightを唯一の高さの基準として使う(固定値を使わない)。
    private var adSize: AdSize { largeAnchoredAdaptiveBanner(width: max(width, 0)) }

    // GADBannerViewはSwiftUI側のframeと無関係に自分自身のサイズで再レイアウトすることがあり、
    // それが原因で広告がこの枠からはみ出し、直下・直上のボタンのタップを奪ってしまう不具合が
    // 確認された。アンカー型アダプティブバナーは仕様上どれだけ大きくても150pt程度に収まるため、
    // 外側を必ずこの上限でclipし、内部の実際のサイズに関係なくヒットテスト領域も確実に制限する。
    private let maxHeight: CGFloat = 150

    @ViewBuilder
    var body: some View {
        if isUITestBannerVisible {
            Color.clear
                .frame(height: 50)
                .accessibilityElement()
                .accessibilityLabel("広告")
                .accessibilityIdentifier("bannerAdContainer")
        } else if !isUITestAdsRemoved {
            Group {
                if shouldShow, width > 0 {
                    BannerRepresentable(
                        unitID: AdsConfiguration.current.bannerAdUnitID,
                        size: adSize,
                        onLoaded: { loaded = true },
                        onFailed: { loaded = false }
                    )
                    .frame(width: adSize.size.width, height: loaded ? adSize.size.height : 0)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("広告")
                    .accessibilityIdentifier("bannerAdContainer")
                }
            }
            // 未ロード中も1ptだけ維持してUIViewを生存させる。広告枠としては
            // 見えず、ロード成功時だけ実サイズへ展開される。
            .frame(height: shouldShow ? (loaded ? min(adSize.size.height, maxHeight) : 1) : 0)
            .clipped()
            .animation(.easeOut(duration: 0.15), value: loaded)
        }
    }

    private var isUITestBannerVisible: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-uiTestingFreeAds")
#else
        false
#endif
    }

    private var isUITestAdsRemoved: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-uiTestingRemovedAds")
#else
        false
#endif
    }

    private var shouldShow: Bool {
        purchases.entitlementCheckCompleted && !purchases.hasRemovedAds &&
        consent.canRequestAds && consent.mobileAdsInitialized &&
        !consent.isPresentingForm && !ads.isPresentingInterstitial &&
        AdsConfiguration.current.canLoadBanner
    }
}

/// GADBannerViewを直接SwiftUIへ渡すと、実機で本番の(仲介ネットワーク経由の)広告を
/// 読み込んだ際に、広告SDK側が自分自身のframeをSwiftUIの指定と無関係に書き換え、
/// その結果ヒットテスト領域も広告SDKの都合で決まってしまい、直下・直上のボタン
/// (追加ボタンやタブバー)のタップを奪う不具合が実機でのみ確認された
/// (Debugのテスト広告は小さく自己伸縮しないため、シミュレーターでは再現しない)。
/// SwiftUIが唯一frameを制御する素のUIViewを間に挟み、GADBannerViewはその中の
/// 子ビューとして扱うことで、広告SDKが何をしてもヒットテスト領域が外側のframeを
/// 超えないようにする(UIViewのhitTestはまず自分自身のboundsで足切りされるため)。
private final class BannerContainerView: UIView {
    weak var bannerView: BannerView?
}

private struct BannerRepresentable: UIViewRepresentable {
    let unitID: String
    let size: AdSize
    let onLoaded: () -> Void
    let onFailed: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLoaded: onLoaded, onFailed: onFailed) }
    func makeUIView(context: Context) -> BannerContainerView {
        let container = BannerContainerView()
        container.clipsToBounds = true

        let view = BannerView(adSize: size)
        view.adUnitID = unitID
        view.delegate = context.coordinator
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        container.bannerView = view

        context.coordinator.scheduleLoad(view, size: size)
        return container
    }
    func updateUIView(_ container: BannerContainerView, context: Context) {
        guard let view = container.bannerView else { return }
        context.coordinator.load(view, size: size)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let onLoaded: () -> Void
        let onFailed: () -> Void
        var requestedSize: CGSize?
        var retryScheduled = false
        init(onLoaded: @escaping () -> Void, onFailed: @escaping () -> Void) {
            self.onLoaded = onLoaded; self.onFailed = onFailed
        }
        func scheduleLoad(_ view: BannerView, size: AdSize) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.load(view, size: size)
            }
        }

        func load(_ view: BannerView, size: AdSize) {
            guard requestedSize != size.size else { return }
            guard let presenter = view.window?.rootViewController ?? Self.activeRootViewController else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.load(view, size: size)
                }
                return
            }
            view.rootViewController = presenter
            requestedSize = size.size
            view.adSize = size
            view.load(Request())
        }
        func bannerViewDidReceiveAd(_ bannerView: BannerView) { onLoaded() }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[Tripory Ads] Banner load failed: \(error.localizedDescription)")
            onFailed()
            requestedSize = nil
            guard !retryScheduled else { return }
            retryScheduled = true
            let size = bannerView.adSize
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self, weak bannerView] in
                guard let self, let bannerView else { return }
                self.retryScheduled = false
                self.load(bannerView, size: size)
            }
        }

        private static var activeRootViewController: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController
        }
    }
}

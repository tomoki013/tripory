import GoogleMobileAds
import SwiftUI
import UIKit

struct RootBannerAd: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ConsentManager.self) private var consent
    @Environment(AdsService.self) private var ads
    @State private var loaded = false

    @ViewBuilder
    var body: some View {
        if isUITestBannerVisible {
            Color.clear
                .frame(height: 50)
                .accessibilityElement()
                .accessibilityLabel("広告")
                .accessibilityIdentifier("bannerAdContainer")
        } else if !isUITestAdsRemoved {
            GeometryReader { proxy in
                let width = max(proxy.size.width, 0)
                if shouldShow, width > 0 {
                    let size = largeAnchoredAdaptiveBanner(width: width)
                    BannerRepresentable(
                        unitID: AdsConfiguration.current.bannerAdUnitID,
                        size: size,
                        onLoaded: { loaded = true },
                        onFailed: { loaded = false }
                    )
                    .frame(width: size.size.width, height: loaded ? size.size.height : 0)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("広告")
                    .accessibilityIdentifier("bannerAdContainer")
                }
            }
            // 未ロード中も1ptだけ維持してUIViewを生存させる。広告枠としては
            // 見えず、ロード成功時だけ実サイズへ展開される。
            .frame(height: shouldShow ? (loaded ? 64 : 1) : 0)
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

private struct BannerRepresentable: UIViewRepresentable {
    let unitID: String
    let size: AdSize
    let onLoaded: () -> Void
    let onFailed: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLoaded: onLoaded, onFailed: onFailed) }
    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: size)
        view.adUnitID = unitID
        view.delegate = context.coordinator
        context.coordinator.scheduleLoad(view, size: size)
        return view
    }
    func updateUIView(_ view: BannerView, context: Context) { context.coordinator.load(view, size: size) }

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

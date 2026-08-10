import GoogleMobileAds
import Observation
import UIKit

@MainActor
@Observable
final class AdsService: NSObject, FullScreenContentDelegate {
    private(set) var isInterstitialLoaded = false
    private(set) var isPresentingInterstitial = false
    private var interstitial: InterstitialAd?
    private var policy = InterstitialPresentationPolicy()
    private var isLoading = false
    private var disabledForPurchase = false

    func loadInterstitialIfEligible(canRequestAds: Bool, hasRemovedAds: Bool) async {
        guard canRequestAds, !hasRemovedAds, !disabledForPurchase, !isLoading, interstitial == nil else { return }
        let config = AdsConfiguration.current
        guard config.canLoadInterstitial else {
            print("[Tripory Ads] Interstitial ID is not configured; interstitials are disabled.")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let ad = try await InterstitialAd.load(with: config.interstitialAdUnitID, request: Request())
            guard !disabledForPurchase else { return }
            ad.fullScreenContentDelegate = self
            interstitial = ad
            isInterstitialLoaded = true
        } catch {
            isInterstitialLoaded = false
            print("[Tripory Ads] Interstitial load failed: \(error.localizedDescription)")
        }
    }

    func presentIfEligible(
        eventID: UUID,
        newlyVisitedCountryCodes: Set<String>,
        canRequestAds: Bool,
        hasRemovedAds: Bool
    ) {
        guard !isPresentingInterstitial,
              policy.shouldPresent(
                eventID: eventID,
                newlyVisitedCountryCodes: newlyVisitedCountryCodes,
                hasRemovedAds: hasRemovedAds,
                canRequestAds: canRequestAds,
                isAdLoaded: isInterstitialLoaded
              ),
              let interstitial else { return }
        self.interstitial = nil
        isInterstitialLoaded = false
        isPresentingInterstitial = true
        interstitial.present(from: nil)
    }

    func disableAds() {
        disabledForPurchase = true
        interstitial = nil
        isInterstitialLoaded = false
    }

    func enableAds() {
        disabledForPurchase = false
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isPresentingInterstitial = false
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        isPresentingInterstitial = false
        print("[Tripory Ads] Interstitial presentation failed: \(error.localizedDescription)")
    }
}

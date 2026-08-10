import AppTrackingTransparency
import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

@MainActor
@Observable
final class ConsentManager {
    private(set) var consentCheckCompleted = false
    private(set) var canRequestAds = false
    private(set) var mobileAdsInitialized = false
    private(set) var privacyOptionsRequired = false
    private(set) var isPresentingForm = false
    private var hasPrepared = false

    func prepareIfEligible(entitlementCheckCompleted: Bool, hasRemovedAds: Bool) async {
        guard entitlementCheckCompleted, !hasRemovedAds, !hasPrepared else { return }
        hasPrepared = true

        let parameters = RequestParameters()
#if ADS_TESTING
        if let geography = ProcessInfo.processInfo.environment["TRIPORY_UMP_GEOGRAPHY"] {
            let debug = DebugSettings()
            if geography.lowercased() == "eea" { debug.geography = .EEA }
            parameters.debugSettings = debug
        }
#endif
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            isPresentingForm = true
            defer { isPresentingForm = false }
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            print("[Tripory Ads] UMP consent update failed: \(error.localizedDescription)")
        }

        consentCheckCompleted = true
        refreshFlags()
        guard canRequestAds else { return }
        await requestTrackingIfNeeded()
        guard !mobileAdsInitialized else { return }
        _ = await MobileAds.shared.start()
        mobileAdsInitialized = true
    }

    func presentPrivacyOptions() async {
        guard privacyOptionsRequired else { return }
        isPresentingForm = true
        defer { isPresentingForm = false }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            print("[Tripory Ads] Privacy options failed: \(error.localizedDescription)")
        }
        refreshFlags()
    }

    private func refreshFlags() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func requestTrackingIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        while UIApplication.shared.applicationState != .active {
            try? await Task.sleep(for: .milliseconds(150))
        }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }
}

import Foundation

struct AdsConfiguration {
    let appID: String
    let bannerAdUnitID: String
    let interstitialAdUnitID: String

    static var current: AdsConfiguration {
        let info = Bundle.main.infoDictionary ?? [:]
        return AdsConfiguration(
            appID: info["GADApplicationIdentifier"] as? String ?? "",
            bannerAdUnitID: info["AdMobBannerAdUnitID"] as? String ?? "",
            interstitialAdUnitID: info["AdMobInterstitialAdUnitID"] as? String ?? ""
        )
    }

    var canLoadBanner: Bool { isConfigured(bannerAdUnitID) }
    var canLoadInterstitial: Bool { isConfigured(interstitialAdUnitID) }

    private func isConfigured(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !value.contains("$(")
    }
}

enum AppLinks {
    static let brand = URL(string: "https://tripory.tmkch.io")!
    static let support = URL(string: "https://tmkch.io/support")!

    static var appStoreID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TriporyAppStoreID") as? String,
              !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }

    static var reviewURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}

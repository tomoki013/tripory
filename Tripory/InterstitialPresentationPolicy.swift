import Foundation

struct InterstitialPresentationPolicy {
    struct Configuration {
        var probability = 0.30
        var minimumInterval: TimeInterval = 15 * 60
        var maximumPerSession = 1
        var skipFirstEligibleEvent = true
    }

    private let configuration: Configuration
    private let defaults: UserDefaults
    private(set) var shownThisSession = 0
    private var evaluatedEvents: Set<UUID> = []

    init(configuration: Configuration = .init(), defaults: UserDefaults = .standard) {
        self.configuration = configuration
        self.defaults = defaults
    }

    mutating func shouldPresent(
        eventID: UUID,
        newlyVisitedCountryCodes: Set<String>,
        hasRemovedAds: Bool,
        canRequestAds: Bool,
        isAdLoaded: Bool,
        now: Date = .now,
        randomValue: Double = Double.random(in: 0..<1)
    ) -> Bool {
        guard evaluatedEvents.insert(eventID).inserted,
              !newlyVisitedCountryCodes.isEmpty,
              !hasRemovedAds,
              canRequestAds,
              isAdLoaded else { return false }

        let firstEventKey = "tripory.interstitial.didConsumeFirstEligibleEvent"
        if configuration.skipFirstEligibleEvent && !defaults.bool(forKey: firstEventKey) {
            defaults.set(true, forKey: firstEventKey)
            return false
        }
        guard shownThisSession < configuration.maximumPerSession else { return false }
        if let last = defaults.object(forKey: "tripory.interstitial.lastShownAt") as? Date,
           now.timeIntervalSince(last) < configuration.minimumInterval { return false }
        guard randomValue < configuration.probability else { return false }

        shownThisSession += 1
        defaults.set(now, forKey: "tripory.interstitial.lastShownAt")
        return true
    }
}

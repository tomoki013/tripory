import Foundation
import Testing
@testable import Tripory

@Suite("インターステシャル表示ポリシー")
struct InterstitialPresentationPolicyTests {
    private func defaults() -> UserDefaults {
        let name = "InterstitialPresentationPolicyTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func configured(
        probability: Double = 1,
        interval: TimeInterval = 900,
        maximum: Int = 1,
        skipFirst: Bool = false,
        defaults: UserDefaults
    ) -> InterstitialPresentationPolicy {
        InterstitialPresentationPolicy(
            configuration: .init(
                probability: probability,
                minimumInterval: interval,
                maximumPerSession: maximum,
                skipFirstEligibleEvent: skipFirst
            ),
            defaults: defaults
        )
    }

    private func evaluate(
        _ policy: inout InterstitialPresentationPolicy,
        id: UUID = UUID(),
        countries: Set<String> = ["FR"],
        removed: Bool = false,
        consent: Bool = true,
        loaded: Bool = true,
        now: Date = Date(timeIntervalSince1970: 10_000),
        random: Double = 0
    ) -> Bool {
        policy.shouldPresent(
            eventID: id,
            newlyVisitedCountryCodes: countries,
            hasRemovedAds: removed,
            canRequestAds: consent,
            isAdLoaded: loaded,
            now: now,
            randomValue: random
        )
    }

    @Test("新規国がなければ表示しない")
    func noNewCountry() { let d = defaults(); var p = configured(defaults: d); #expect(!evaluate(&p, countries: [])) }

    @Test("広告削除済みなら表示しない")
    func purchased() { let d = defaults(); var p = configured(defaults: d); #expect(!evaluate(&p, removed: true)) }

    @Test("同意未取得なら表示しない")
    func noConsent() { let d = defaults(); var p = configured(defaults: d); #expect(!evaluate(&p, consent: false)) }

    @Test("広告が未ロードなら表示しない")
    func notLoaded() { let d = defaults(); var p = configured(defaults: d); #expect(!evaluate(&p, loaded: false)) }

    @Test("最初の対象イベントを一度だけスキップする")
    func skipsFirst() {
        let d = defaults(); var p = configured(skipFirst: true, defaults: d)
        #expect(!evaluate(&p))
        #expect(evaluate(&p))
    }

    @Test("確率0では表示せず確率1では表示する")
    func probabilityBoundaries() {
        let d0 = defaults(); var never = configured(probability: 0, defaults: d0)
        #expect(!evaluate(&never, random: 0))
        let d1 = defaults(); var always = configured(probability: 1, defaults: d1)
        #expect(evaluate(&always, random: 0.999))
    }

    @Test("15分未満では再表示しない")
    func interval() {
        let d = defaults(); var first = configured(defaults: d)
        let date = Date(timeIntervalSince1970: 10_000)
        #expect(evaluate(&first, now: date))
        var nextSession = configured(defaults: d)
        #expect(!evaluate(&nextSession, now: date.addingTimeInterval(899)))
        #expect(evaluate(&nextSession, now: date.addingTimeInterval(900)))
    }

    @Test("1セッション1回まで")
    func sessionLimit() {
        let d = defaults(); var p = configured(interval: 0, defaults: d)
        #expect(evaluate(&p))
        #expect(!evaluate(&p))
    }

    @Test("同じ保存イベントを二重判定しない")
    func duplicateEvent() {
        let d = defaults(); var p = configured(interval: 0, maximum: 2, defaults: d); let id = UUID()
        #expect(evaluate(&p, id: id))
        #expect(!evaluate(&p, id: id))
    }

    @Test("複数の新規国でも広告判定は一回だけ")
    func multipleCountriesStillOneEvent() {
        let d = defaults(); var p = configured(interval: 0, maximum: 2, defaults: d); let id = UUID()
        #expect(evaluate(&p, id: id, countries: ["FR", "BE"]))
        #expect(!evaluate(&p, id: id, countries: ["FR", "BE"]))
    }
}

import Foundation
import SwiftData
import Testing
@testable import Tripory

@MainActor
@Suite("ストア操作(レコード生成・訪問済みの取り消し・プロフィール)")
struct ModelContextTests {

    // MARK: - record(for:)

    @Test("初めての国コードならレコードを新規作成する")
    func recordCreatesWhenMissing() throws {
        let context = try TestSupport.makeContext()
        let record = context.record(for: "FR")
        #expect(record.code == "FR")
        #expect(record.status == CountryStatus.none)
        #expect(try context.fetchCount(FetchDescriptor<CountryRecord>()) == 1)
    }

    @Test("同じ国コードを何度引いてもレコードは1件のまま")
    func recordIsIdempotent() throws {
        let context = try TestSupport.makeContext()
        context.record(for: "FR").status = .visited
        let again = context.record(for: "FR")
        #expect(again.status == .visited)
        #expect(try context.fetchCount(FetchDescriptor<CountryRecord>()) == 1)
    }

    @Test("国コードごとに別のレコードになる")
    func recordsAreSeparatePerCode() throws {
        let context = try TestSupport.makeContext()
        context.record(for: "FR").status = .visited
        context.record(for: "IT").status = .wantToGo
        #expect(context.record(for: "FR").status == .visited)
        #expect(context.record(for: "IT").status == .wantToGo)
        #expect(try context.fetchCount(FetchDescriptor<CountryRecord>()) == 2)
    }

    // MARK: - revertStatusIfOrphaned

    @Test("その国の訪問先が残っていなければ訪問済みを取り消す")
    func revertsWhenNoStopsRemain() throws {
        let context = try TestSupport.makeContext()
        context.record(for: "FR").status = .visited

        context.revertStatusIfOrphaned(codes: ["FR"], homeCountryCode: "JP")

        #expect(context.record(for: "FR").status == CountryStatus.none)
    }

    @Test("他の旅にまだ訪問先が残っていれば訪問済みのまま")
    func keepsStatusWhenStopsRemain() throws {
        let context = try TestSupport.makeContext()
        context.record(for: "FR").status = .visited
        TestSupport.insertTrip(into: context, stops: [(code: "FR", start: "2019-05-02", end: nil)])
        try context.save()

        context.revertStatusIfOrphaned(codes: ["FR"], homeCountryCode: "JP")

        #expect(context.record(for: "FR").status == .visited)
    }

    @Test("住んでいる国は訪問先がなくても訪問済みのまま保つ")
    func keepsHomeCountryVisited() throws {
        let context = try TestSupport.makeContext()
        context.record(for: "JP").status = .visited

        context.revertStatusIfOrphaned(codes: ["JP"], homeCountryCode: "JP")

        #expect(context.record(for: "JP").status == .visited)
    }

    @Test("複数の国をまとめて判定でき、条件を満たす国だけ取り消される")
    func revertsOnlyOrphanedCodes() throws {
        let context = try TestSupport.makeContext()
        for code in ["FR", "IT", "JP"] { context.record(for: code).status = .visited }
        // イタリアだけ他の旅に残っている
        TestSupport.insertTrip(into: context, stops: [(code: "IT", start: "2019-05-08", end: nil)])
        try context.save()

        context.revertStatusIfOrphaned(codes: ["FR", "IT", "JP"], homeCountryCode: "JP")

        #expect(context.record(for: "FR").status == CountryStatus.none) // 孤立→取り消し
        #expect(context.record(for: "IT").status == .visited)           // 訪問先が残っている
        #expect(context.record(for: "JP").status == .visited)           // 住んでいる国
    }

    @Test("空の集合を渡しても何も壊れない")
    func revertWithEmptySetIsNoop() throws {
        let context = try TestSupport.makeContext()
        context.record(for: "FR").status = .visited

        context.revertStatusIfOrphaned(codes: [], homeCountryCode: "JP")

        #expect(context.record(for: "FR").status == .visited)
    }

    // MARK: - primaryUserProfile

    @Test("プロフィールは初回に作られ、以降は同じものを返す")
    func primaryUserProfileIsCreatedOnce() throws {
        let context = try TestSupport.makeContext()
        let first = context.primaryUserProfile()
        first.homeHeroScale = 2.0
        try context.save()

        let second = context.primaryUserProfile()

        #expect(second.id == "primary")
        #expect(second.homeHeroScale == 2.0)
        #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
    }

    @Test("新しいプロフィールの初期値は中央・等倍・写真なし")
    func newProfileDefaults() throws {
        let context = try TestSupport.makeContext()
        let profile = context.primaryUserProfile()
        #expect(profile.homeHeroPhotoData == nil)
        #expect(profile.homeHeroFocalX == 0.5)
        #expect(profile.homeHeroFocalY == 0.5)
        #expect(profile.homeHeroScale == 1.0)
        #expect(profile.onboardingCompletedAt == nil)
    }

    // MARK: - 旅の削除

    @Test("旅を削除すると訪問先も一緒に消える(カスケード)")
    func deletingTripCascadesToStops() throws {
        let context = try TestSupport.makeContext()
        let trip = TestSupport.insertTrip(into: context, stops: [
            (code: "FR", start: "2019-05-02", end: nil),
            (code: "IT", start: "2019-05-08", end: nil),
        ])
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<TripStop>()) == 2)

        context.delete(trip)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<TripStop>()) == 0)
    }

    @Test("旅を削除してから孤立判定すると訪問済みが取り消される")
    func deleteTripThenRevert() throws {
        let context = try TestSupport.makeContext()
        context.record(for: "FR").status = .visited
        let trip = TestSupport.insertTrip(into: context, stops: [(code: "FR", start: "2019-05-02", end: nil)])
        try context.save()

        context.delete(trip)
        try context.save()
        context.revertStatusIfOrphaned(codes: ["FR"], homeCountryCode: "JP")

        #expect(context.record(for: "FR").status == CountryStatus.none)
    }
}

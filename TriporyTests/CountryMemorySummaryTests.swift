import Foundation
import SwiftData
import Testing
@testable import Tripory

@MainActor
@Suite("国ごとの集計と関係性の判定")
struct CountryMemorySummaryTests {

    /// 集計を組み立て、指定した国のサマリーを取り出す。
    private func summary(
        for code: String,
        records: [CountryRecord] = [],
        stops: [TripStop] = [],
        homePeriods: [HomeCountryPeriod] = []
    ) throws -> CountryMemorySummary {
        let all = CountryMemorySummary.build(records: records, stops: stops, homePeriods: homePeriods)
        return try #require(all.first { $0.country.code == code })
    }

    @Test("カタログのすべての国ぶんのサマリーが作られる")
    func buildCoversEveryCountry() {
        let all = CountryMemorySummary.build(records: [], stops: [], homePeriods: [])
        #expect(all.count == CountryCatalog.totalCount)
    }

    @Test("記録が何もなければ未訪問・0回・0日")
    func emptySummary() throws {
        let france = try summary(for: "FR")
        #expect(france.visitCount == 0)
        #expect(france.totalDays == 0)
        #expect(france.status == CountryStatus.none)
        #expect(france.firstVisitDate == nil)
        #expect(france.latestVisitDate == nil)
        #expect(france.coverPhotoData == nil)
        #expect(france.relationship == .unvisited)
    }

    @Test("訪問回数と合計日数がその国の訪問先だけから集計される")
    func countsOnlyMatchingCountry() throws {
        let stops = [
            TripStop(order: 0, countryCode: "FR", startDate: TestSupport.date("2019-05-02"), endDate: TestSupport.date("2019-05-07")),
            TripStop(order: 1, countryCode: "IT", startDate: TestSupport.date("2019-05-08"), endDate: TestSupport.date("2019-05-10")),
            TripStop(order: 2, countryCode: "FR", startDate: TestSupport.date("2025-10-10"), endDate: nil),
        ]
        let france = try summary(for: "FR", stops: stops)
        #expect(france.visitCount == 2)
        #expect(france.totalDays == 7) // 6日 + 1日
    }

    @Test("初回・最新の訪問日が正しく取り出される")
    func firstAndLatestVisitDate() throws {
        let stops = [
            TripStop(order: 0, countryCode: "FR", startDate: TestSupport.date("2025-10-10")),
            TripStop(order: 1, countryCode: "FR", startDate: TestSupport.date("2019-05-02")),
            TripStop(order: 2, countryCode: "FR", startDate: TestSupport.date("2022-01-01")),
        ]
        let france = try summary(for: "FR", stops: stops)
        #expect(france.firstVisitDate == TestSupport.date("2019-05-02"))
        #expect(france.latestVisitDate == TestSupport.date("2025-10-10"))
    }

    @Test("表紙写真はいちばん新しい訪問の写真を使う")
    func coverPhotoUsesLatestVisit() throws {
        let old = Data("old".utf8)
        let recent = Data("recent".utf8)
        let stops = [
            TripStop(order: 0, countryCode: "FR", startDate: TestSupport.date("2019-05-02"), photos: [old]),
            TripStop(order: 1, countryCode: "FR", startDate: TestSupport.date("2025-10-10"), photos: [recent]),
        ]
        let france = try summary(for: "FR", stops: stops)
        #expect(france.coverPhotoData == recent)
        #expect(france.allPhotoData == [old, recent])
    }

    @Test("写真のない訪問は写真一覧に含まれない")
    func photosSkipStopsWithoutPhoto() throws {
        let photo = Data("photo".utf8)
        let stops = [
            TripStop(order: 0, countryCode: "FR", startDate: TestSupport.date("2019-05-02")),
            TripStop(order: 1, countryCode: "FR", startDate: TestSupport.date("2020-05-02"), photos: [photo]),
        ]
        let france = try summary(for: "FR", stops: stops)
        #expect(france.allPhotoData == [photo])
        #expect(france.coverPhotoData == photo)
    }

    @Test("ステータスはCountryRecordから引き継がれる")
    func statusComesFromRecord() throws {
        let record = CountryRecord(code: "IS", status: .wantToGo)
        let iceland = try summary(for: "IS", records: [record])
        #expect(iceland.status == .wantToGo)
    }

    @Test("住んでいた履歴があればhasLivedThereが立つ")
    func hasLivedThereFromHomePeriods() throws {
        let periods = [HomeCountryPeriod(countryCode: "JP")]
        let japan = try summary(for: "JP", homePeriods: periods)
        let france = try summary(for: "FR", homePeriods: periods)
        #expect(japan.hasLivedThere)
        #expect(!france.hasLivedThere)
    }

    // MARK: - relationship

    @Test("行きたい国はwishlistになる")
    func relationshipWishlist() throws {
        let iceland = try summary(for: "IS", records: [CountryRecord(code: "IS", status: .wantToGo)])
        #expect(iceland.relationship == .wishlist)
    }

    @Test(
        "訪問回数に応じて関係性が変わる",
        arguments: [
            (1, CountryRelationship.oneVisit),
            (2, CountryRelationship.twoVisits),
            (3, CountryRelationship.frequent),
            (7, CountryRelationship.frequent),
        ]
    )
    func relationshipByVisitCount(visits: Int, expected: CountryRelationship) throws {
        let stops = (0..<visits).map { index in
            TripStop(order: index, countryCode: "FR", startDate: TestSupport.date("2019-05-02"))
        }
        let france = try summary(for: "FR", stops: stops)
        #expect(france.relationship == expected)
    }

    @Test("住んだ国は訪問回数より優先される")
    func livedBeatsVisitCount() throws {
        let stops = (0..<5).map { index in
            TripStop(order: index, countryCode: "JP", startDate: TestSupport.date("2019-05-02"))
        }
        let japan = try summary(
            for: "JP",
            stops: stops,
            homePeriods: [HomeCountryPeriod(countryCode: "JP")]
        )
        #expect(japan.relationship == .lived)
    }

    @Test("訪問済みなら行きたい国のステータスより訪問回数が優先される")
    func visitCountBeatsWishlist() throws {
        let france = try summary(
            for: "FR",
            records: [CountryRecord(code: "FR", status: .wantToGo)],
            stops: [TripStop(order: 0, countryCode: "FR", startDate: TestSupport.date("2019-05-02"))]
        )
        #expect(france.relationship == .oneVisit)
    }

    @Test("サマリーのidは国コードと一致する")
    func idIsCountryCode() throws {
        let france = try summary(for: "FR")
        #expect(france.id == "FR")
    }
}

import Foundation
import Testing
@testable import Tripory

@Suite("国カタログ")
struct CountryCatalogTests {

    @Test("国コードから国を引ける")
    func lookupByCode() throws {
        let japan = try #require(CountryCatalog.byCode["JP"])
        #expect(japan.code == "JP")
    }

    @Test("存在しないコードはnilになる")
    func lookupUnknownCode() {
        #expect(CountryCatalog.byCode["ZZ"] == nil)
    }

    @Test("totalCountは全件数と一致する")
    func totalCountMatchesAll() {
        #expect(CountryCatalog.totalCount == CountryCatalog.all.count)
    }

    @Test("国コードは重複しない")
    func codesAreUnique() {
        let codes = CountryCatalog.all.map(\.code)
        #expect(Set(codes).count == codes.count)
    }

    @Test("byCodeは全件を網羅する")
    func byCodeCoversAll() {
        #expect(CountryCatalog.byCode.count == CountryCatalog.all.count)
    }

    @Test(
        "国コードから国旗の絵文字を作れる",
        arguments: [("JP", "🇯🇵"), ("FR", "🇫🇷"), ("US", "🇺🇸"), ("IT", "🇮🇹")]
    )
    func flagFromCode(code: String, expected: String) throws {
        let country = try #require(CountryCatalog.byCode[code])
        #expect(country.flag == expected)
    }

    @Test("すべての国が名前を持つ")
    func everyCountryHasName() {
        #expect(CountryCatalog.all.allSatisfy { !$0.name.isEmpty })
    }

    @Test("大陸ごとの絞り込みは全件の分割になっている")
    func continentsPartitionAll() {
        let byContinent = Continent.allCases.flatMap { CountryCatalog.countries(in: $0) }
        #expect(byContinent.count == CountryCatalog.totalCount)
        #expect(Set(byContinent.map(\.code)) == Set(CountryCatalog.all.map(\.code)))
    }

    @Test("大陸ごとの絞り込みは、その大陸の国だけを返す")
    func countriesInContinentBelongToIt() {
        for continent in Continent.allCases {
            let countries = CountryCatalog.countries(in: continent)
            #expect(countries.allSatisfy { $0.continent == continent })
        }
    }

    @Test("同じコードの国は等価で、Setで重複しない")
    func countryEquatableByCode() throws {
        let a = try #require(CountryCatalog.byCode["JP"])
        let b = try #require(CountryCatalog.byCode["JP"])
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
    }
}

@Suite("国のステータス")
struct CountryStatusTests {

    @Test("訪問済みだけが「行ったことがある」と数えられる")
    func countsAsVisited() {
        #expect(CountryStatus.visited.countsAsVisited)
        #expect(!CountryStatus.wantToGo.countsAsVisited)
        #expect(!CountryStatus.none.countsAsVisited)
    }

    @Test("rawValue経由で往復できる")
    func roundTripsThroughRawValue() {
        for status in CountryStatus.allCases {
            #expect(CountryStatus(rawValue: status.rawValue) == status)
        }
    }

    @Test("すべてのステータスが表示名を持つ")
    func everyStatusHasDisplayName() {
        #expect(CountryStatus.allCases.allSatisfy { !$0.displayName.isEmpty })
    }

    @Test("CountryRecordのstatusはrawValueと同期する")
    func recordStatusSyncsWithRawValue() {
        let record = CountryRecord(code: "FR")
        #expect(record.status == CountryStatus.none)

        record.status = .visited
        #expect(record.statusRaw == CountryStatus.visited.rawValue)

        record.statusRaw = CountryStatus.wantToGo.rawValue
        #expect(record.status == .wantToGo)
    }

    @Test("未知のrawValueは未訪問として扱う(壊れたデータへの保険)")
    func unknownRawValueFallsBackToNone() {
        let record = CountryRecord(code: "FR")
        record.statusRaw = "garbage"
        #expect(record.status == CountryStatus.none)
    }
}

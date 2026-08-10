import Foundation

struct CountryMemorySummary: Identifiable {
    let country: Country
    let status: CountryStatus
    let visitCount: Int
    let totalDays: Int
    let firstVisitDate: Date?
    let latestVisitDate: Date?
    let coverPhotoData: Data?
    let allPhotoData: [Data]
    let hasLivedThere: Bool

    var id: String { country.code }

    static func build(
        records: [CountryRecord],
        stops: [TripStop],
        homePeriods: [HomeCountryPeriod]
    ) -> [CountryMemorySummary] {
        let statusByCode = Dictionary(uniqueKeysWithValues: records.map { ($0.code, $0.status) })
        let coverByCode = Dictionary(uniqueKeysWithValues: records.map { ($0.code, $0.coverPhotoData) })
        let stopsByCode = Dictionary(grouping: stops, by: \.countryCode)
        let livedCodes = Set(homePeriods.map(\.countryCode))

        return CountryCatalog.all.map { country in
            let countryStops = (stopsByCode[country.code] ?? []).sorted { $0.startDate < $1.startDate }
            let photos = countryStops.flatMap(\.photos)
            // 詳細ページと同じく、ユーザーが明示的に選んだ表紙写真を最優先する
            // (以前はここが旅の写真からの自動選択しか見ておらず、詳細ページで
            // 表紙を変更してもコレクション一覧のサムネには反映されなかった)。
            let cover = (coverByCode[country.code] ?? nil) ?? countryStops.reversed().flatMap(\.photos).first
            return CountryMemorySummary(
                country: country,
                status: statusByCode[country.code] ?? .none,
                visitCount: countryStops.count,
                totalDays: countryStops.reduce(0) { $0 + $1.dayCount },
                firstVisitDate: countryStops.first?.startDate,
                latestVisitDate: countryStops.last?.startDate,
                coverPhotoData: cover,
                allPhotoData: photos,
                hasLivedThere: livedCodes.contains(country.code)
            )
        }
    }
}

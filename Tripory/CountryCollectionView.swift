import SwiftUI
import SwiftData

/// 条件でしぼりこんだ国の一覧。大陸別カードや「行きたい国」タイルなどから
/// タップで開いて、そこから各国の詳細へ進める。
struct CountryCollectionView: View {
    enum Kind: Hashable {
        case continent(Continent)
        case status(CountryStatus)
        case visited

        var title: String {
            switch self {
            case .continent(let c): return c.displayName
            case .status(let s): return s.displayName
            case .visited: return String(localized: "訪れた国")
            }
        }
    }

    let kind: Kind

    @Query private var records: [CountryRecord]

    private var statusByCode: [String: CountryStatus] {
        Dictionary(uniqueKeysWithValues: records.map { ($0.code, $0.status) })
    }

    private var countries: [Country] {
        switch kind {
        case .continent(let continent):
            return CountryCatalog.countries(in: continent)
        case .status(let status):
            let codes = records.filter { $0.status == status }.map(\.code)
            return codes.compactMap { CountryCatalog.byCode[$0] }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .visited:
            let codes = records.filter { $0.status.countsAsVisited }.map(\.code)
            return codes.compactMap { CountryCatalog.byCode[$0] }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        Group {
            if countries.isEmpty {
                ContentUnavailableView(
                    "まだありません",
                    systemImage: "globe",
                    description: Text("右下の+から旅やステータスを記録してみましょう。")
                )
            } else {
                List {
                    ForEach(countries) { country in
                        NavigationLink(value: country) {
                            CountryRow(country: country, status: statusByCode[country.code] ?? .none)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

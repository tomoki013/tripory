import Foundation
import SwiftUI

enum Continent: String, CaseIterable, Identifiable, Codable {
    case asia, europe, africa, northAmerica, southAmerica, oceania

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .asia: return String(localized: "アジア")
        case .europe: return String(localized: "ヨーロッパ")
        case .africa: return String(localized: "アフリカ")
        case .northAmerica: return String(localized: "北アメリカ")
        case .southAmerica: return String(localized: "南アメリカ")
        case .oceania: return String(localized: "オセアニア")
        }
    }

    /// SF Symbol名。Appleが提供する地域別グローブを使い分ける(6大陸に対し3種類を色で差別化)。
    var symbolName: String {
        switch self {
        case .asia, .oceania: return "globe.asia.australia.fill"
        case .europe, .africa: return "globe.europe.africa.fill"
        case .northAmerica, .southAmerica: return "globe.americas.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .asia: return .pink
        case .europe: return .indigo
        case .africa: return .brown
        case .northAmerica: return .blue
        case .southAmerica: return .green
        case .oceania: return .cyan
        }
    }
}

struct Country: Identifiable, Hashable {
    let code: String
    let continent: Continent

    var id: String { code }

    var name: String { CountryCatalog.localizedName(for: code) }

    var flag: String {
        code.unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value).map(String.init)
        }.joined()
    }
}

enum CountryCatalog {
    // 国連加盟国+バチカン・コソボ・台湾・パレスチナ(ISO 3166-1 alpha-2)
    static let codesByContinent: [Continent: [String]] = [
        .asia: [
            "AF", "AM", "AZ", "BH", "BD", "BT", "BN", "KH", "CN", "CY",
            "GE", "IN", "ID", "IR", "IQ", "IL", "JP", "JO", "KZ", "KW",
            "KG", "LA", "LB", "MY", "MV", "MN", "MM", "NP", "KP", "KR",
            "OM", "PK", "PS", "PH", "QA", "SA", "SG", "LK", "SY", "TW",
            "TJ", "TH", "TL", "TR", "TM", "AE", "UZ", "VN", "YE",
        ],
        .europe: [
            "AL", "AD", "AT", "BY", "BE", "BA", "BG", "HR", "CZ", "DK",
            "EE", "FI", "FR", "DE", "GR", "HU", "IS", "IE", "IT", "XK",
            "LV", "LI", "LT", "LU", "MT", "MD", "MC", "ME", "NL", "MK",
            "NO", "PL", "PT", "RO", "RU", "SM", "RS", "SK", "SI", "ES",
            "SE", "CH", "UA", "GB", "VA",
        ],
        .africa: [
            "DZ", "AO", "BJ", "BW", "BF", "BI", "CV", "CM", "CF", "TD",
            "KM", "CG", "CD", "CI", "DJ", "EG", "GQ", "ER", "SZ", "ET",
            "GA", "GM", "GH", "GN", "GW", "KE", "LS", "LR", "LY", "MG",
            "MW", "ML", "MR", "MU", "MA", "MZ", "NA", "NE", "NG", "RW",
            "ST", "SN", "SC", "SL", "SO", "ZA", "SS", "SD", "TZ", "TG",
            "TN", "UG", "ZM", "ZW",
        ],
        .northAmerica: [
            "AG", "BS", "BB", "BZ", "CA", "CR", "CU", "DM", "DO", "SV",
            "GD", "GT", "HT", "HN", "JM", "MX", "NI", "PA", "KN", "LC",
            "VC", "TT", "US",
        ],
        .southAmerica: [
            "AR", "BO", "BR", "CL", "CO", "EC", "GY", "PY", "PE", "SR",
            "UY", "VE",
        ],
        .oceania: [
            "AU", "FJ", "KI", "MH", "FM", "NR", "NZ", "PW", "PG", "WS",
            "SB", "TO", "TV", "VU",
        ],
    ]

    static let all: [Country] = codesByContinent
        .flatMap { continent, codes in
            codes.map { Country(code: $0, continent: continent) }
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

    static let byCode: [String: Country] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.code, $0) }
    )

    private static let allByContinent: [Continent: [Country]] = Dictionary(
        grouping: all, by: \.continent
    )

    static var totalCount: Int { all.count }

    static func countries(in continent: Continent) -> [Country] {
        allByContinent[continent] ?? []
    }

    static func localizedName(for code: String) -> String {
        if let name = Locale.current.localizedString(forRegionCode: code) {
            return name
        }
        // Locale が返さないコードのフォールバック
        switch code {
        case "XK": return String(localized: "コソボ")
        default: return code
        }
    }
}

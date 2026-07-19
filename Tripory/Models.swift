import Foundation
import SwiftData
import SwiftUI

/// 国との関わりを表すステータス。
enum CountryStatus: String, CaseIterable, Identifiable, Codable {
    case none
    case wantToGo
    case visited

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return String(localized: "未訪問")
        case .wantToGo: return String(localized: "行きたい")
        case .visited: return String(localized: "訪問済み")
        }
    }

    var color: Color {
        switch self {
        case .none: return .secondary
        case .wantToGo: return .orange
        case .visited: return .teal
        }
    }

    var iconName: String {
        switch self {
        case .none: return "circle.dashed"
        case .wantToGo: return "star.fill"
        case .visited: return "checkmark.circle.fill"
        }
    }

    /// 実際にその国へ足を踏み入れたことがあるか
    var countsAsVisited: Bool { self == .visited }
}

@Model
final class CountryRecord {
    // 既存ストアからの軽量マイグレーションのため、後から追加した非オプショナル属性には
    // 宣言時にデフォルト値を持たせる(initのデフォルト引数はマイグレーションには使われない)。
    @Attribute(.unique) var code: String = ""
    var statusRaw: String = CountryStatus.none.rawValue
    /// 「行きたい国」に登録した理由などの自由メモ
    var note: String = ""
    /// 国の詳細ページのヒーローに使う、ユーザーが明示的に選んだ表紙写真。
    /// 未設定なら旅の写真から自動で選ぶ。
    @Attribute(.externalStorage) var coverPhotoData: Data?

    init(code: String, status: CountryStatus = .none, note: String = "") {
        self.code = code
        self.statusRaw = status.rawValue
        self.note = note
    }

    var status: CountryStatus {
        get { CountryStatus(rawValue: statusRaw) ?? .none }
        set { statusRaw = newValue.rawValue }
    }

    var country: Country? { CountryCatalog.byCode[code] }
}

/// 1回の海外旅行。複数の国を訪問順に持てる(周遊旅行に対応)。
@Model
final class Trip {
    var title: String = ""
    var note: String = ""
    var createdAt: Date = Date.now
    /// 表紙に使う写真を明示的に選んだ場合のみ設定される。未設定なら最初の訪問先の写真を自動で使う。
    var heroPhotoData: Data?
    @Relationship(deleteRule: .cascade, inverse: \TripStop.trip)
    var stops: [TripStop] = []

    init(title: String = "", note: String = "", createdAt: Date = .now) {
        self.title = title
        self.note = note
        self.createdAt = createdAt
        self.stops = []
    }

    var sortedStops: [TripStop] { stops.sorted { $0.order < $1.order } }
    var startDate: Date? { sortedStops.first?.startDate }
    var endDate: Date? {
        sortedStops.last?.endDate ?? sortedStops.last?.startDate
    }
    var countries: [Country] { sortedStops.compactMap(\.country) }

    /// 「フランス → イタリア」のような訪問先の並び
    var routeDescription: String {
        sortedStops.compactMap(\.country?.name).joined(separator: " → ")
    }

    /// この旅で実際に過ごした合計日数(訪問先ごとの日数の合計)
    var totalDays: Int {
        sortedStops.reduce(0) { $0 + $1.dayCount }
    }
}

/// 旅の中の1つの訪問先(国+期間+写真)。orderで訪問順を保持する。
@Model
final class TripStop {
    var order: Int = 0
    var countryCode: String = ""
    var startDate: Date = Date.now
    var endDate: Date?
    var photos: [Data] = []
    var trip: Trip?

    init(
        order: Int,
        countryCode: String,
        startDate: Date,
        endDate: Date? = nil,
        photos: [Data] = []
    ) {
        self.order = order
        self.countryCode = countryCode
        self.startDate = startDate
        self.endDate = endDate
        self.photos = photos
    }

    var country: Country? { CountryCatalog.byCode[countryCode] }

    /// この訪問先で過ごした日数(終了日がなければ1日として数える)
    var dayCount: Int {
        guard let endDate else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(days + 1, 1)
    }
}

/// 「住んでいる国」を設定した履歴。引っ越しなどで変わっても過去の記録を辿れるようにする。
@Model
final class HomeCountryPeriod {
    var countryCode: String = ""
    var setAt: Date = Date.now

    init(countryCode: String, setAt: Date = .now) {
        self.countryCode = countryCode
        self.setAt = setAt
    }

    var country: Country? { CountryCatalog.byCode[countryCode] }
}

/// 端末内に1件だけ保持するユーザープロフィール。
/// 既存の旅行データとは独立して追加し、ストアを作り直さずに段階移行できるようにする。
@Model
final class UserProfile {
    @Attribute(.unique) var id: String = "primary"
    @Attribute(.externalStorage) var homeHeroPhotoData: Data?
    var homeHeroFocalX: Double = 0.5
    var homeHeroFocalY: Double = 0.5
    var homeHeroScale: Double = 1.0
    var onboardingCompletedAt: Date?
    var createdAt: Date = Date.now

    init() {}
}

extension ModelContext {
    /// メインプロフィールを取得し、まだなければ1件だけ作成する。
    func primaryUserProfile() -> UserProfile {
        let primaryID = "primary"
        let predicate = #Predicate<UserProfile> { $0.id == primaryID }
        if let existing = try? fetch(FetchDescriptor(predicate: predicate)).first {
            return existing
        }
        let profile = UserProfile()
        insert(profile)
        return profile
    }

    /// 国コードに対応するレコードを取得(なければ作成)
    func record(for code: String) -> CountryRecord {
        let predicate = #Predicate<CountryRecord> { $0.code == code }
        if let existing = try? fetch(FetchDescriptor(predicate: predicate)).first {
            return existing
        }
        let record = CountryRecord(code: code)
        insert(record)
        return record
    }

    /// 旅(または訪問先)の削除後に呼ぶ。その国を参照する記録が他になければ、
    /// 「訪問済み」を取り消す(住んでいる国は除く)。
    func revertStatusIfOrphaned(codes: Set<String>, homeCountryCode: String) {
        for code in codes {
            guard code != homeCountryCode else { continue }
            let predicate = #Predicate<TripStop> { $0.countryCode == code }
            let remaining = (try? fetchCount(FetchDescriptor(predicate: predicate))) ?? 0
            if remaining == 0 {
                record(for: code).status = .none
            }
        }
    }
}

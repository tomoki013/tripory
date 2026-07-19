import SwiftUI

enum CountryRelationship: Int, CaseIterable, Hashable {
    case unvisited
    case wishlist
    case oneVisit
    case twoVisits
    case frequent
    case lived

    var label: LocalizedStringKey {
        switch self {
        case .unvisited: return "未訪問"
        case .wishlist: return "行きたい国"
        case .oneVisit: return "1回訪問"
        case .twoVisits: return "2回訪問"
        case .frequent: return "3回以上訪問"
        case .lived: return "住んだ国"
        }
    }

    var color: Color {
        switch self {
        case .unvisited: return Color.gray.opacity(0.24)
        case .wishlist: return .triporyBlue
        case .oneVisit: return .triporyGold
        case .twoVisits: return .triporyRust
        case .frequent: return .triporyCoral
        case .lived: return .triporySage
        }
    }
}

extension CountryMemorySummary {
    var relationship: CountryRelationship {
        if hasLivedThere { return .lived }
        if visitCount >= 3 { return .frequent }
        if visitCount == 2 { return .twoVisits }
        if visitCount == 1 { return .oneVisit }
        if status == .wantToGo { return .wishlist }
        return .unvisited
    }
}

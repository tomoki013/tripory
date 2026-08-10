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

    // Midnight Atlas: Goldは「住んだ国」専用の特別な色として予約し、訪問回数の
    // 段階はCoralファミリー内の別RGBで表現する(GoldとCoralの役割を混同しないため)。
    // 以前はopacityだけで段階を分けていたが、地球儀の描画(MKPolygonRenderer)が
    // fillColorのalphaを一律で上書きするため、1回・2回・3回以上がすべて同じ色に
    // 潰れてしまっていた。RGB自体を変えることでどの画面でも区別できるようにする。
    var color: Color {
        switch self {
        case .unvisited: return Color.gray.opacity(0.24)
        case .wishlist: return .triporyHorizonBlue
        case .oneVisit: return .triporyCoralLight
        case .twoVisits: return .triporyCoral
        case .frequent: return .triporyRust
        case .lived: return .triporyGold
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

import SwiftUI

enum RootDestination: Hashable {
    case home
    case trips
    case world
    case me

    var label: LocalizedStringKey {
        switch self {
        case .home: return "ホーム"
        case .trips: return "旅の記録"
        case .world: return "世界"
        case .me: return "マイページ"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .trips: return "doc.text"
        case .world: return "globe.americas"
        case .me: return "person.crop.circle"
        }
    }
}

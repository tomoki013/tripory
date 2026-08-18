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

    /// UIテスト(App Storeスクリーンショット撮影など)がタブバーを言語非依存で
    /// タップできるようにするための識別子。
    var identifierSuffix: String {
        switch self {
        case .home: return "home"
        case .trips: return "trips"
        case .world: return "world"
        case .me: return "me"
        }
    }
}

import SwiftUI

enum RootDestination: Hashable {
    case home
    case trips
    /// タブとしては選択されない特殊な項目。タップした瞬間に旅の記録シートを開き、
    /// 選択状態は直前のタブへ戻す(RootView側でハンドリング)。
    case add
    case world
    case me

    var label: LocalizedStringKey {
        switch self {
        case .home: return "ホーム"
        case .trips: return "旅の記録"
        case .add: return "旅を記録する"
        case .world: return "国一覧"
        case .me: return "設定"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .trips: return "doc.text"
        case .add: return "plus.circle.fill"
        case .world: return "globe.americas"
        case .me: return "gearshape"
        }
    }
}

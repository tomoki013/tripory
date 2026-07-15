import SwiftUI

/// フローティング追加ボタンなど、画面全体に重なるUIの表示/非表示を
/// 個々の画面(全画面地図など)から制御するための共有状態。
final class ChromeVisibility: ObservableObject {
    @Published var isFABHidden = false
}

import SwiftUI
import UIKit

/// アプリ全体で使う背景色。ライト/ダークで色を固定し、画面ごとに背景がバラつかないようにする。
extension Color {
    static let appBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.075, blue: 0.07, alpha: 1)
            : UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1)
    })

    static let appCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.145, blue: 0.14, alpha: 1)
            : UIColor.white
    })
}

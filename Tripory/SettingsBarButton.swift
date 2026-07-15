import SwiftUI

/// 各タブ画面の右上に固定で表示する設定ボタン。ホーム画面は独自ヘッダーに内蔵しているため対象外。
struct SettingsBarButton: ToolbarContent {
    @Binding var isPresented: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isPresented = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
            }
        }
    }
}

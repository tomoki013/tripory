import SwiftUI

/// マップの表示スタイル(カラー/白黒)と、訪問済みのみ表示の独立したトグルをまとめたコントロール。
/// ホーム画面・全画面マップの両方から使い回す。
struct MapModeControls: View {
    @Binding var baseStyle: MapDisplayMode
    @Binding var visitedOnly: Bool
    /// 全画面マップ上に浮かせる場合はtrue(半透明素材の背景にする)
    var floating = false

    var body: some View {
        HStack(spacing: 8) {
            styleSwitcher
            visitedOnlyChip
        }
    }

    private var styleSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(MapDisplayMode.allCases, id: \.self) { mode in
                styleButton(mode)
            }
        }
        .padding(3)
        .background(backgroundStyle, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private func styleButton(_ mode: MapDisplayMode) -> some View {
        let isSelected = baseStyle == mode
        return Button {
            withAnimation(.snappy(duration: 0.2)) { baseStyle = mode }
        } label: {
            Text(mode.label)
                .font(.caption2.bold())
                .foregroundStyle(isSelected ? .white : (floating ? .primary : .secondary))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AnyShapeStyle(teaOrangeGradient) : AnyShapeStyle(.clear), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var visitedOnlyChip: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { visitedOnly.toggle() }
        } label: {
            Label("訪問済みのみ", systemImage: visitedOnly ? "checkmark.circle.fill" : "circle")
                .font(.caption2.bold())
                .labelStyle(.titleAndIcon)
                .foregroundStyle(visitedOnly ? .white : (floating ? .primary : .secondary))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(visitedOnly ? AnyShapeStyle(teaOrangeGradient) : AnyShapeStyle(.clear), in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(3)
        .background(backgroundStyle, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private var backgroundStyle: AnyShapeStyle {
        floating ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.appCard)
    }

    private var teaOrangeGradient: LinearGradient {
        LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing)
    }
}

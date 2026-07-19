import SwiftUI

/// 3D地球の下部に置く凡例カード。「あなたの世界の見え方」を2列で示す。
struct GlobeLegendView: View {
    @State private var isExpanded = true

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.snappy(duration: 0.24)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("あなたの世界の見え方")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "凡例を閉じる" : "凡例を開く")

            if isExpanded {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 11) {
                    ForEach(CountryRelationship.allCases.reversed(), id: \.self) { relationship in
                        HStack(spacing: 9) {
                            Circle()
                                .fill(relationship.color)
                                .frame(width: 11, height: 11)
                                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: relationship == .lived ? 2 : 0))
                            Text(relationship.label)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .triporyGlass(
            in: RoundedRectangle(cornerRadius: 22),
            tint: Color.triporyNavy.opacity(0.6),
            opaqueFallback: Color.triporyNavy
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

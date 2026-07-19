import SwiftUI
import SwiftData

/// 「旅の記録」ページに置く、住んでいる国の履歴。矢印で過去にさかのぼって見られる。
/// 現在の国は自動的に訪問済み扱いだが、過去の国は「訪問済みから外す」で取り消せる。
struct HomeCountryHistorySection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HomeCountryPeriod.setAt) private var periods: [HomeCountryPeriod]
    @State private var index: Int?

    private var currentIndex: Int {
        min(index ?? max(periods.count - 1, 0), max(periods.count - 1, 0))
    }

    private var isLatest: Bool { currentIndex == periods.count - 1 }

    var body: some View {
        if !periods.isEmpty {
            let period = periods[currentIndex]

            VStack(alignment: .leading, spacing: 14) {
                header

                HStack(spacing: 12) {
                    arrowButton(system: "chevron.left", disabled: currentIndex == 0) { move(-1) }

                    countryDisplay(for: period)
                        .frame(maxWidth: .infinity)
                        .id(period.persistentModelID)
                        .transition(.opacity)

                    arrowButton(system: "chevron.right", disabled: isLatest) { move(1) }
                }

                if periods.count > 1 {
                    pageDots
                }

                if !isLatest {
                    removeButton(for: period)
                }
            }
            .padding(18)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "house.fill")
                .font(.caption2)
                .foregroundStyle(.indigo)
            Text("住んでいる国")
                .font(.caption.bold())
                .triporyTracking(1.5)
                .foregroundStyle(.secondary)
            Spacer()
            if isLatest {
                Text("現在")
                    .font(.caption2.bold())
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.teal.opacity(0.12), in: Capsule())
            }
        }
    }

    private func countryDisplay(for period: HomeCountryPeriod) -> some View {
        HStack(spacing: 14) {
            if let country = period.country {
                Text(country.flag)
                    .font(.system(size: 40))
                    .frame(width: 58, height: 58)
                    .background(Color.primary.opacity(0.05), in: Circle())
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
                    .frame(width: 58, height: 58)
                    .background(Color.primary.opacity(0.05), in: Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(period.country?.name ?? period.countryCode)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(period.country != nil ? .primary : .secondary)
                Label(rangeText(for: period, index: currentIndex), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
    }

    private func arrowButton(system: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.subheadline.bold())
                .foregroundStyle(disabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.teal))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(disabled ? Color.primary.opacity(0.04) : Color.teal.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(periods.indices, id: \.self) { i in
                Circle()
                    .fill(i == currentIndex ? Color.teal : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func removeButton(for period: HomeCountryPeriod) -> some View {
        Button(role: .destructive) {
            withAnimation { modelContext.record(for: period.countryCode).status = .none }
        } label: {
            Label("訪問済みから外す", systemImage: "minus.circle")
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
    }

    private func move(_ delta: Int) {
        withAnimation(.snappy(duration: 0.25)) {
            index = min(max(currentIndex + delta, 0), periods.count - 1)
        }
    }

    private func rangeText(for period: HomeCountryPeriod, index: Int) -> String {
        let start = yearMonth(period.setAt)
        guard index < periods.count - 1 else { return "\(start) 〜 \(String(localized: "現在"))" }
        return "\(start) 〜 \(yearMonth(periods[index + 1].setAt))"
    }

    private func yearMonth(_ date: Date) -> String {
        date.formatted(.dateTime.year().month())
    }
}

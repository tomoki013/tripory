import SwiftUI
import SwiftData

/// 旅の記録 = 左に年のタイムラインレール、右に写真カードを並べる構成。
struct TripTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTrips: [Trip]
    @State private var editingTrip: Trip?
    @State private var deletingTrip: Trip?
    @Environment(TripFlowCoordinator.self) private var tripFlow

    private var trips: [Trip] {
        allTrips.filter { !$0.stops.isEmpty }.sorted {
            ($0.startDate ?? $0.createdAt) > ($1.startDate ?? $1.createdAt)
        }
    }

    private var tripsByYear: [(year: Int, trips: [Trip])] {
        let grouped = Dictionary(grouping: trips) {
            Calendar.current.component(.year, from: $0.startDate ?? $0.createdAt)
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    EditorialTitle(text: "旅の記録")
                        .padding(.horizontal, 20)
                        .padding(.top, 18)

                    if trips.isEmpty {
                        EmptyCollectionState(
                            title: "旅の記録がありません",
                            message: "最初の旅を残すと、訪れた国と写真があなたの世界に加わります。",
                            actionTitle: "旅を記録する",
                            action: { tripFlow.presentNewTrip() }
                        )
                        .padding(.top, 70)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(tripsByYear.enumerated()), id: \.element.year) { index, group in
                                yearSection(
                                    group.year,
                                    trips: group.trips,
                                    isLast: index == tripsByYear.count - 1
                                )
                            }
                        }
                        .padding(.horizontal, 18)

                        VStack(alignment: .leading, spacing: 12) {
                            TriporySectionHeader(title: "住んでいた国")
                            HomeCountryHistorySection()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                // 右下に浮かぶ追加ボタンの分、最後のカードが隠れないよう余白を確保する。
                .padding(.bottom, 90)
            }
            .scrollIndicators(.hidden)
            .background(Color.triporyCanvas)
            .hidesNavigationBar()
            .navigationDestination(for: Trip.self) { TripDetailView(trip: $0) }
            .navigationDestination(for: Country.self) { CountryDetailView(country: $0) }
            .sheet(item: $editingTrip) { trip in
                TripFormView(editingTrip: trip)
            }
            .alert("この旅を削除しますか?", isPresented: Binding(
                get: { deletingTrip != nil },
                set: { if !$0 { deletingTrip = nil } }
            )) {
                Button("削除する", role: .destructive) {
                    if let deletingTrip { delete(deletingTrip) }
                }
                Button("キャンセル", role: .cancel) { deletingTrip = nil }
            }
        }
    }

    private func yearSection(_ year: Int, trips: [Trip], isLast: Bool) -> some View {
        let isCurrentYear = year == Calendar.current.component(.year, from: .now)
        return HStack(alignment: .top, spacing: 12) {
            // 年のレール(ラベル+ドット+縦線)。今年だけ強調する。
            VStack(spacing: 6) {
                Text(String(year))
                    .font(.system(.subheadline, design: .serif, weight: isCurrentYear ? .bold : .semibold))
                    .foregroundStyle(isCurrentYear ? Color.triporyCoral : Color.triporyInk)
                if isCurrentYear {
                    // 今年: リング付きの大きめドット
                    Circle()
                        .fill(Color.triporyCoral)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.triporyCoral.opacity(0.3), lineWidth: 4))
                        .padding(.vertical, 2)
                } else {
                    Circle()
                        .fill(Color.triporyCoral.opacity(0.55))
                        .frame(width: 7, height: 7)
                }
                Rectangle()
                    .fill(isLast ? Color.clear : Color.triporyDivider)
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 44)
            .accessibilityHidden(true)

            VStack(spacing: 13) {
                ForEach(trips) { trip in
                    NavigationLink(value: trip) {
                        TripCoverCard(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("編集", systemImage: "pencil") {
                            editingTrip = trip
                        }
                        Button("削除", systemImage: "trash", role: .destructive) {
                            deletingTrip = trip
                        }
                    }
                    .accessibilityAction(named: "削除") { deletingTrip = trip }
                    .accessibilityLabel("\(String(year))年、\(trip.title)")
                }
            }
            .padding(.bottom, 22)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func delete(_ trip: Trip) {
        let codes = Set(trip.stops.map(\.countryCode))
        withAnimation { modelContext.delete(trip) }
        modelContext.revertStatusIfOrphaned(codes: codes, homeCountryCode: homeCountryCode)
        deletingTrip = nil
    }
}

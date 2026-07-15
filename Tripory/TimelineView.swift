import SwiftUI
import SwiftData

struct TripTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTrips: [Trip]
    @State private var showingAddTrip = false
    @State private var showingSettings = false

    private var trips: [Trip] {
        allTrips.filter { !$0.stops.isEmpty }.sorted {
            ($0.startDate ?? $0.createdAt) > ($1.startDate ?? $1.createdAt)
        }
    }

    private var tripsByYear: [(year: Int, trips: [Trip])] {
        let grouped = Dictionary(grouping: trips) {
            Calendar.current.component(.year, from: $0.startDate ?? $0.createdAt)
        }
        return grouped.keys.sorted(by: >).map { (year: $0, trips: grouped[$0]!) }
    }

    private var totalDays: Int {
        trips.reduce(0) { $0 + $1.totalDays }
    }

    private var daysSinceLastTrip: Int? {
        guard let last = trips.first?.startDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: .now).day
    }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    VStack(spacing: 0) {
                        HomeCountryHistorySection()
                            .padding(.horizontal)
                            .padding(.top, 12)
                        emptyState
                    }
                } else {
                    List {
                        HomeCountryHistorySection()
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        statsHeader
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        ForEach(tripsByYear, id: \.year) { group in
                            Section {
                                ForEach(group.trips) { trip in
                                    NavigationLink(value: trip) {
                                        TripRow(trip: trip)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            let codes = Set(trip.stops.map(\.countryCode))
                                            withAnimation { modelContext.delete(trip) }
                                            modelContext.revertStatusIfOrphaned(codes: codes, homeCountryCode: homeCountryCode)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text("\(String(group.year)) ・ \(group.trips.count) \(String(localized: "回"))")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("旅の記録")
            .toolbar { SettingsBarButton(isPresented: $showingSettings) }
            .navigationDestination(for: Country.self) { country in
                CountryDetailView(country: country)
            }
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .sheet(isPresented: $showingAddTrip) {
                TripFormView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var statsHeader: some View {
        HStack(spacing: 10) {
            statTile(icon: "airplane", value: "\(trips.count)", label: "旅の回数", color: .teal)
            statTile(icon: "moon.stars.fill", value: "\(totalDays)", label: "合計日数", color: .indigo)
            statTile(
                icon: "hourglass",
                value: daysSinceLastTrip.map { "\($0)" } ?? "-",
                label: "最後の海外旅行から",
                color: .orange
            )
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func statTile(icon: String, value: String, label: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("旅の記録がありません", systemImage: "airplane.departure")
        } description: {
            Text("最初の旅を記録して、あなたの旅の年表を作りましょう。")
        } actions: {
            Button("旅を記録する") { showingAddTrip = true }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
        }
    }
}

struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            flagStack
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.title.isEmpty ? routeText : trip.title)
                    .font(.headline)
                Text("\(routeText) ・ \(dateText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var flagStack: some View {
        ZStack {
            ForEach(Array(trip.countries.prefix(3).enumerated()), id: \.offset) { index, country in
                Text(country.flag)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.05), in: Circle())
                    .offset(x: CGFloat(index) * 14)
            }
        }
        .frame(width: 44 + CGFloat(max(trip.countries.count - 1, 0)) * 14, height: 44, alignment: .leading)
    }

    private var routeText: String { trip.routeDescription }

    private var dateText: String {
        guard let start = trip.startDate else { return "" }
        return start.formatted(.dateTime.year().month(.abbreviated).day())
    }
}

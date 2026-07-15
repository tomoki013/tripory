import SwiftUI
import SwiftData

struct HomeView: View {
    /// 「旅の回数」など旅にまつわるタイルから旅の記録タブへ切り替えるためのコールバック
    var onShowTrips: () -> Void = {}

    @Query private var records: [CountryRecord]
    @Query private var trips: [Trip]
    @State private var showingSettings = false
    @AppStorage("mapDisplayMode") private var mapDisplayModeRaw = MapDisplayMode.color.rawValue
    @AppStorage("mapVisitedOnly") private var visitedOnly = false

    private var displayMode: MapDisplayMode { MapDisplayMode(rawValue: mapDisplayModeRaw) ?? .color }

    private var displayModeBinding: Binding<MapDisplayMode> {
        Binding(get: { displayMode }, set: { mapDisplayModeRaw = $0.rawValue })
    }

    private var visitedRecords: [CountryRecord] {
        records.filter { $0.status.countsAsVisited && $0.country != nil }
    }

    private var visitedCount: Int { visitedRecords.count }

    private var wantToGoCount: Int {
        records.filter { $0.status == .wantToGo }.count
    }

    private var totalVisits: Int {
        trips.filter { !$0.stops.isEmpty }.count
    }

    private var progressPercent: Int {
        Int((Double(visitedCount) / Double(CountryCatalog.totalCount) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    VStack(alignment: .trailing, spacing: 8) {
                        MapModeControls(baseStyle: displayModeBinding, visitedOnly: $visitedOnly)
                        mapCard
                    }
                    statRow
                    continentBreakdown
                    flagWall
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationBarHidden(true)
            .navigationDestination(for: Country.self) { country in
                CountryDetailView(country: country)
            }
            .navigationDestination(for: CountryCollectionView.Kind.self) { kind in
                CountryCollectionView(kind: kind)
            }
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRIPORY")
                        .font(.caption.bold())
                        .tracking(3)
                        .foregroundStyle(.teal)
                    Text("あなたの旅の記録")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                }
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 46, height: 46)
                        .background(Color.appCard, in: Circle())
                        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                }
            }
            Rectangle()
                .fill(LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .opacity(0.5)
        }
        .padding(.top, 8)
    }

    private var mapCard: some View {
        NavigationLink {
            FullMapView()
        } label: {
            ZStack(alignment: .bottomLeading) {
                WorldMapCard(records: records, displayMode: displayMode, visitedOnly: visitedOnly)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(visitedCount) / \(CountryCatalog.totalCount) \(String(localized: "か国"))")
                        .font(.title3.bold())
                    Text("\(progressPercent)% \(String(localized: "制覇"))")
                        .font(.caption)
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(9)
                    .background(.black.opacity(0.35), in: Circle())
                    .padding(10)
            }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            Button(action: onShowTrips) {
                statTile(icon: "airplane", value: "\(totalVisits)", label: "旅の回数", color: .teal)
            }
            .buttonStyle(.plain)

            NavigationLink(value: CountryCollectionView.Kind.status(.wantToGo)) {
                statTile(icon: "star.fill", value: "\(wantToGoCount)", label: "行きたい国", color: .orange)
            }
            .buttonStyle(.plain)

            NavigationLink(value: CountryCollectionView.Kind.visited) {
                statTile(icon: "globe.americas.fill", value: "\(progressPercent)%", label: "制覇率", color: .indigo)
            }
            .buttonStyle(.plain)
        }
    }

    private func statTile(icon: String, value: String, label: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    private var continentBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("大陸別")
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            ForEach(Continent.allCases) { continent in
                let total = CountryCatalog.countries(in: continent).count
                let visited = visitedRecords.filter { $0.country?.continent == continent }.count
                NavigationLink(value: CountryCollectionView.Kind.continent(continent)) {
                    continentRow(continent, visited: visited, total: total)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func continentRow(_ continent: Continent, visited: Int, total: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: continent.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(continent.tintColor)
                .frame(width: 38, height: 38)
                .background(continent.tintColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(continent.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(visited) / \(total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                GeometryReader { geo in
                    let ratio = total > 0 ? CGFloat(visited) / CGFloat(total) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(continent.tintColor.opacity(0.12))
                        Capsule()
                            .fill(continent.tintColor)
                            .frame(width: max(geo.size.width * ratio, ratio > 0 ? 6 : 0))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var flagWall: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: CountryCollectionView.Kind.visited) {
                HStack {
                    Text("訪れた国")
                        .font(.caption.bold())
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !visitedRecords.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            if visitedRecords.isEmpty {
                Text("まだ記録がありません。右下の+から最初の旅を記録しましょう。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                    ForEach(visitedRecords.compactMap(\.country).sorted {
                        $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    }) { country in
                        NavigationLink(value: country) {
                            Text(country.flag)
                                .font(.system(size: 32))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .padding(.bottom, 90)
    }
}

import SwiftUI
import SwiftData

/// ホーム = 全画面のヒーロー写真の上に、My World・国数・最近の旅・最近増えた国を重ねる構成。
struct HomeView: View {
    var onShowTrips: () -> Void = {}
    var onShowWorld: () -> Void = {}
    var onCreateTrip: () -> Void = {}

    @Query private var records: [CountryRecord]
    @Query private var trips: [Trip]
    @Query private var stops: [TripStop]
    @Query private var periods: [HomeCountryPeriod]
    @Query private var profiles: [UserProfile]
    @AppStorage("homeCountryCode") private var homeCountryCode = ""

    private var profile: UserProfile? { profiles.first }

    private var summaries: [CountryMemorySummary] {
        CountryMemorySummary.build(records: records, stops: stops, homePeriods: periods)
    }

    private var visitedCount: Int {
        // 住んでいる国も「訪れた国」の一部として数える。
        summaries.filter { $0.status.countsAsVisited }.count
    }

    private var recentTrip: Trip? {
        trips.filter { !$0.stops.isEmpty }.max {
            ($0.startDate ?? $0.createdAt) < ($1.startDate ?? $1.createdAt)
        }
    }

    private var recentlyAdded: [CountryMemorySummary] {
        summaries
            .filter { $0.country.code != homeCountryCode && $0.firstVisitDate != nil }
            .sorted { ($0.firstVisitDate ?? .distantPast) > ($1.firstVisitDate ?? .distantPast) }
    }

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        topBar
                        identityBlock
                        Spacer(minLength: 28)
                        bottomBlock
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
            }
            .background { heroBackground }
            .hidesNavigationBar()
            .navigationDestination(for: Trip.self) { TripDetailView(trip: $0) }
            .navigationDestination(for: Country.self) { CountryDetailView(country: $0) }
        }
#if DEBUG
        // デザイン確認用: 実際のプッシュ遷移で詳細画面まで入る(モーダルではないので
        // タブバーやセーフエリアの見え方が本番と同じになる)。
        .task {
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains("-qaTripDetail") || arguments.contains("-qaCountryDetail") else { return }
            try? await Task.sleep(for: .seconds(2)) // シードデータの投入を待つ
            if arguments.contains("-qaTripDetail"), let recentTrip {
                path.append(recentTrip)
            } else if arguments.contains("-qaCountryDetail"), let france = CountryCatalog.byCode["FR"] {
                path.append(france)
            }
        }
#endif
    }

    // MARK: - Background

    private var heroBackground: some View {
        ZStack {
            if let profile, profile.homeHeroPhotoData != nil {
                HomeHeroCropView(profile: profile)
            } else {
                PhotoPlaceholderView(symbol: "globe.asia.australia.fill", title: "My World")
            }

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.52), location: 0),
                    .init(color: .black.opacity(0.12), location: 0.34),
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.66), location: 0.86),
                    .init(color: .black.opacity(0.82), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: - Top

    private var topBar: some View {
        HStack {
            Text(verbatim: "TRIPORY")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.top, 10)
    }

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "My World")
                .font(.system(size: 54, design: .serif))
                .padding(.top, 22)
            Text("旅で集めた、わたしの世界")
                .font(.subheadline.weight(.medium))
                .opacity(0.88)
                .padding(.top, 8)

            Text("\(visitedCount)")
                .font(.system(size: 76, weight: .regular, design: .serif).monospacedDigit())
                .padding(.top, 26)
            Text(verbatim: visitedCount == 1 ? "COUNTRY" : "COUNTRIES")
                .font(.caption.weight(.bold))
                .tracking(2.4)
                .opacity(0.85)

            // 素の.glassは背景の写真の明るさをそのまま拾うため、明るい写真だと文字が
            // 読みにくくなることがある。.glassProminentで暗色を敷き、写真の内容に
            // 関わらず白文字が安定して読めるようにする。
            Button("世界地図を見る", systemImage: "globe.asia.australia", action: onShowWorld)
                .buttonStyle(.glassProminent)
                .font(.subheadline.weight(.semibold))
                .tint(.black.opacity(0.45))
                .foregroundStyle(.white)
                .padding(.top, 24)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("My World、訪れた国\(visitedCount)か国、旅で集めたわたしの世界")
    }

    // MARK: - Bottom

    @ViewBuilder
    private var bottomBlock: some View {
        if let recentTrip {
            VStack(alignment: .leading, spacing: 24) {
                recentTripRow(recentTrip)
                if !recentlyAdded.isEmpty { recentCountriesRail }
            }
        } else {
            emptyTripCTA
        }
    }

    private func recentTripRow(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("最近の旅")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            NavigationLink(value: trip) {
                HStack(spacing: 13) {
                    tripThumbnail(trip)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trip.title.isEmpty ? trip.routeDescription : trip.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let start = trip.startDate {
                            Text(dateRangeText(start: start, end: trip.endDate))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.66))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("最近の旅、\(trip.title)")
        }
    }

    @ViewBuilder
    private func tripThumbnail(_ trip: Trip) -> some View {
        let data = trip.heroPhotoData ?? trip.sortedStops.flatMap(\.photos).first
        Group {
            if let data, let image = UIImage(data: data) {
                FilledPhoto(uiImage: image)
            } else {
                ZStack {
                    Color.white.opacity(0.16)
                    Image(systemName: "airplane")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(Circle())
        .contentShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
    }

    private var recentCountriesRail: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("最近増えた国")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Button(action: onShowWorld) {
                    Text("すべて見る")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(recentlyAdded.prefix(6)) { summary in
                        NavigationLink(value: summary.country) {
                            RecentCountryCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 96)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -24)
            .contentMargins(.horizontal, 24, for: .scrollContent)
        }
    }

    private var emptyTripCTA: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ここから、あなたの世界が育っていきます。")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(.white)
            Text("最初の旅を残すと、訪れた国と写真がコレクションに加わります。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineSpacing(4)
            Button(action: onCreateTrip) {
                Text("最初の旅を記録する")
                    .font(.headline)
                    .foregroundStyle(Color.triporyNavy)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    private func dateRangeText(start: Date, end: Date?) -> String {
        let startText = start.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        guard let end, !Calendar.current.isDate(end, inSameDayAs: start) else { return startText }
        return "\(startText) - \(end.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))"
    }
}

/// ホーム下部「最近増えた国」用の小さな写真カード(名前+初訪問年)。
struct RecentCountryCard: View {
    let summary: CountryMemorySummary

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = summary.coverPhotoData, let image = UIImage(data: data) {
                    FilledPhoto(uiImage: image)
                } else {
                    LinearGradient(
                        colors: [summary.country.continent.tintColor.opacity(0.8), Color.triporyNavy],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: 124, height: 96)

            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(summary.country.flag) \(summary.country.name)")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                if let first = summary.firstVisitDate {
                    Text(String(Calendar.current.component(.year, from: first)))
                        .font(.caption2)
                        .opacity(0.75)
                }
            }
            .foregroundStyle(.white)
            .padding(9)
        }
        .frame(width: 124, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.country.name)、\(summary.visitCount)回訪問")
    }
}

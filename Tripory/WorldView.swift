import SwiftUI
import SwiftData

enum WorldMode: String, CaseIterable, Identifiable {
    case collection
    case globe
    case flatMap
    var id: String { rawValue }
}

struct WorldView: View {
    enum Filter: CaseIterable, Identifiable {
        case visited, wishlist, all
        var id: Self { self }
        var title: LocalizedStringKey {
            switch self {
            case .visited: return "訪れた国"
            case .wishlist: return "行きたい国"
            case .all: return "すべて"
            }
        }
    }

    enum Sort: CaseIterable, Identifiable {
        case latest, first, visits, alphabetical
        var id: Self { self }
        var title: LocalizedStringKey {
            switch self {
            case .latest: return "最近訪れた順"
            case .first: return "初めて訪れた順"
            case .visits: return "訪問回数順"
            case .alphabetical: return "国名順"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var records: [CountryRecord]
    @Query private var stops: [TripStop]
    @Query private var periods: [HomeCountryPeriod]
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @State private var mode: WorldMode = .globe
    @State private var filter: Filter = .visited
    @State private var sort: Sort = .latest
    @State private var selectedCode: String?
    @State private var recenterToken = 0

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-qaCollection") {
            _mode = State(initialValue: .collection)
        } else if arguments.contains("-qaFlatMap") {
            _mode = State(initialValue: .flatMap)
        } else {
            _mode = State(initialValue: .globe)
        }
#endif
    }

    private var summaries: [CountryMemorySummary] {
        CountryMemorySummary.build(records: records, stops: stops, homePeriods: periods)
    }

    private func matchesFilter(_ summary: CountryMemorySummary, _ filter: Filter) -> Bool {
        switch filter {
        case .visited: return summary.visitCount > 0 || summary.status.countsAsVisited
        case .wishlist: return summary.status == .wantToGo
        case .all: return summary.visitCount > 0 || summary.status != .none
        }
    }

    private var collection: [CountryMemorySummary] {
        // 住んでいる国もコレクションの一員として表示する。
        let filtered = summaries.filter { matchesFilter($0, filter) }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .latest:
                return (lhs.latestVisitDate ?? .distantPast) > (rhs.latestVisitDate ?? .distantPast)
            case .first:
                return (lhs.firstVisitDate ?? .distantPast) > (rhs.firstVisitDate ?? .distantPast)
            case .visits:
                if lhs.visitCount == rhs.visitCount {
                    return lhs.country.name.localizedStandardCompare(rhs.country.name) == .orderedAscending
                }
                return lhs.visitCount > rhs.visitCount
            case .alphabetical:
                return lhs.country.name.localizedStandardCompare(rhs.country.name) == .orderedAscending
            }
        }
    }

    /// いちばん最近「初めて訪れた」国にNEWバッジを付ける。
    private var newestFirstVisitCode: String? {
        summaries
            .filter { $0.country.code != homeCountryCode && $0.firstVisitDate != nil }
            .max { ($0.firstVisitDate ?? .distantPast) < ($1.firstVisitDate ?? .distantPast) }?
            .country.code
    }

    private var selectedSummary: CountryMemorySummary? {
        summaries.first { $0.country.code == selectedCode }
    }

    /// 地球儀に出す国。住んでいる国は常に表示し、それ以外はコレクションと同じfilterに従う
    /// (既定の「訪れた国」なら行きたい国は塗られず、地球儀が実際に行った国だけになる)。
    private var globeSummaries: [CountryMemorySummary] {
        summaries.filter { summary in
            summary.country.code == homeCountryCode || matchesFilter(summary, filter)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch mode {
                case .collection: collectionMode
                case .globe: mapMode(isFlat: false)
                case .flatMap: mapMode(isFlat: true)
                }
            }
            .background(mode == .collection ? Color.triporyCanvas : Color.triporyNavy)
            .hidesNavigationBar()
            .accessibilityIdentifier(worldModeAccessibilityIdentifier)
            .navigationDestination(for: Country.self) { CountryDetailView(country: $0) }
            // リキッドグラスは背景色の変化を自前で追従しようとするため、切り替えを
            // ゆっくりアニメーションすると「ガラスの色が遅れて追いつく」ように見える。
            // 背景色そのものは即座に切り替え、レイアウトの入れ替わりだけを短く馴染ませる。
            .animation(.easeOut(duration: 0.12), value: mode)
        }
    }

    private var worldModeAccessibilityIdentifier: String {
        switch mode {
        case .collection: return "worldCollectionScreen"
        case .globe: return "worldGlobeScreen"
        case .flatMap: return "worldFlatMapScreen"
        }
    }

    // MARK: - Collection

    private var collectionMode: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    Text("あなたの国コレクション")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.triporyInk)
                    Spacer()
                    viewModeSwitcher(dark: false)
                }
                .padding(.top, 14)

                collectionControls

                if collection.isEmpty {
                    EmptyCollectionState(
                        title: "まだコレクションがありません",
                        message: "旅を記録するか、行きたい国を追加するとここに並びます。"
                    )
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(collection) { summary in
                            NavigationLink(value: summary.country) {
                                CountryCoverCard(
                                    summary: summary,
                                    showsNewBadge: summary.country.code == newestFirstVisitCode
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if filter != .all {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { filter = .all }
                        } label: {
                            HStack(spacing: 8) {
                                Text("すべての国を見る")
                                Image(systemName: "arrow.right")
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .tint(Color.triporyNavy)
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var collectionControls: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(Filter.allCases) { item in
                        filterChip(item)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            CircleGlassMenu(systemImage: "arrow.up.arrow.down", label: "並べ替え", tint: Color.triporyInk) {
                Picker("並べ替え", selection: $sort) {
                    ForEach(Sort.allCases) { Text($0.title).tag($0) }
                }
            }
        }
    }

    /// 選択中はコーラルの塗り(glassProminent)、それ以外は素のガラス。
    @ViewBuilder
    private func filterChip(_ item: Filter) -> some View {
        let title = Text(item.title).font(.caption.weight(.semibold))
        if filter == item {
            Button {} label: { title }
                .buttonStyle(.glassProminent)
                .tint(Color.triporyCoral)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button {
                withAnimation(.snappy(duration: 0.2)) { filter = item }
            } label: { title }
                .buttonStyle(.glass)
                .tint(Color.triporyInk)
        }
    }

    // MARK: - Map (3D地球儀 / 平面の世界地図)

    private func mapMode(isFlat: Bool) -> some View {
        ZStack(alignment: .top) {
            GlobeMapView(
                summaries: globeSummaries,
                homeCountryCode: homeCountryCode,
                selectedCode: selectedCode,
                recenterToken: recenterToken,
                isFlat: isFlat,
                onSelectCode: { selectedCode = $0 }
            )
            .ignoresSafeArea()
            .accessibilityLabel(isFlat ? "全世界地図" : "インタラクティブな3D地球")

            if !isFlat {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    // カメラは球の上半分だけが画面に収まるよう引きの構図になっているため、
                    // 円の幾何学的な中心は画面のかなり下(見えている範囲の外)にある。
                    // 見えている弧の頂点(画面上部)を基準に、中心は下に大きくずらして近似する。
                    let globeRadius = width * 0.5
                    let globeCenter = CGPoint(x: width * 0.5, y: globeRadius * 1.9)

                    ZStack {
                        // 太陽の反射光(スペキュラハイライト)。左上、氷雲のあたりに小さく強い光を置き、
                        // 「光が当たっている感」を球の表面上に出す。
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color(red: 1, green: 0.93, blue: 0.78).opacity(0.2),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: width * 0.16
                        )
                        .frame(width: width * 0.32, height: width * 0.32)
                        .position(x: globeCenter.x - globeRadius * 0.42, y: globeCenter.y - globeRadius * 0.86)
                        .blendMode(.screen)

                        // 大気の縁の光(リムライト)。球の輪郭に沿ってHorizon Blueのハローを重ね、
                        // 「宇宙に浮かぶ地球」の発光感を近似する。
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    colors: [
                                        Color.triporyHorizonBlue.opacity(0.85),
                                        Color.triporyHorizonBlue.opacity(0.15),
                                        Color.triporyHorizonBlue.opacity(0.05),
                                        Color.triporyHorizonBlue.opacity(0.55),
                                        Color.triporyHorizonBlue.opacity(0.85),
                                    ],
                                    center: .center
                                ),
                                lineWidth: width * 0.045
                            )
                            .frame(width: globeRadius * 2, height: globeRadius * 2)
                            .position(globeCenter)
                            .blur(radius: width * 0.035)
                            .blendMode(.plusLighter)
                            .opacity(0.85)
                    }
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }

            HStack(alignment: .center, spacing: 12) {
                Text("マイワールドマップ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                Spacer(minLength: 8)

                CircleGlassMenu(systemImage: "slider.horizontal.3", label: "表示オプション", tint: .white, size: .large) {
                    Picker("表示する国", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.title).tag($0) }
                    }
                    Divider()
                    Button("住んでいる国を中心に戻す", systemImage: "scope") { recenterToken += 1 }
                }

                // コレクション/地球儀/平面地図の切り替えは、どの画面にいても
                // 同じ位置・同じ3つのアイコンで統一する(前は画面ごとに別のボタン・別の
                // アイコンだったため、切り替え方法がわかりにくいという指摘があった)。
                viewModeSwitcher(dark: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            VStack {
                Spacer()
                if let selectedSummary {
                    globeSelectionCard(selectedSummary)
                } else {
                    GlobeLegendView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    /// コレクション/地球儀/平面地図を3択のカプセル型セグメントで切り替える。
    /// collectionMode・mapMode両方から全く同じ見た目・同じ位置で呼び出すことで、
    /// 「切り替えボタンの場所やアイコンが画面ごとに違って迷う」ことがないようにする。
    private func viewModeSwitcher(dark: Bool) -> some View {
        HStack(spacing: 2) {
            viewModeSegment(symbol: "square.grid.2x2.fill", label: "コレクション", isActive: mode == .collection, dark: dark) {
                switchMode(.collection)
            }
            viewModeSegment(symbol: "globe.asia.australia.fill", label: "3D地球儀", isActive: mode == .globe, dark: dark) {
                switchMode(.globe)
            }
            viewModeSegment(symbol: "map.fill", label: "平面地図", isActive: mode == .flatMap, dark: dark) {
                switchMode(.flatMap)
            }
        }
        .padding(3)
        .background(
            dark ? Color.white.opacity(0.16) : Color.triporyInk.opacity(0.07),
            in: Capsule()
        )
        .overlay(
            Capsule().stroke(dark ? .white.opacity(0.18) : Color.triporyInk.opacity(0.12), lineWidth: 1)
        )
    }

    private func viewModeSegment(
        symbol: String,
        label: LocalizedStringKey,
        isActive: Bool,
        dark: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .foregroundStyle(
                    isActive
                        ? Color.triporyMidnight
                        : (dark ? .white.opacity(0.85) : Color.triporyInk.opacity(0.55))
                )
                .background(
                    // Midnight Atlas: モード切り替えの選択状態はGold(ブランド色)で統一する。
                    isActive ? Color.triporyGold : .clear,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func switchMode(_ newMode: WorldMode) {
        selectedCode = nil
        mode = newMode
    }

    private func globeSelectionCard(_ summary: CountryMemorySummary) -> some View {
        HStack(spacing: 14) {
            if let data = summary.coverPhotoData, let image = UIImage(data: data) {
                FilledPhoto(uiImage: image)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Text(summary.country.flag)
                    .font(.largeTitle)
                    .frame(width: 64, height: 64)
                    .background(summary.relationship.color.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.country.name)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(.white)
                Text(summary.relationship.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(summary.relationship.color)
                if summary.visitCount > 0 {
                    Text("\(summary.visitCount)回 ・ \(summary.totalDays)日")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            Spacer()

            if summary.relationship == .unvisited {
                Button("行きたい国に追加", systemImage: "bookmark.fill") {
                    modelContext.record(for: summary.country.code).status = .wantToGo
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .labelStyle(.iconOnly)
                .tint(Color.triporyBlue)
            } else {
                NavigationLink(value: summary.country) {
                    Label("国の詳細を開く", systemImage: "arrow.right")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(Color.triporyCoral)
            }
        }
        .padding(14)
        .triporyGlass(
            in: RoundedRectangle(cornerRadius: 22),
            tint: Color.triporyNavy.opacity(0.6),
            opaqueFallback: Color.triporyNavy
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .overlay(alignment: .topTrailing) {
            Button("選択を解除", systemImage: "xmark") { selectedCode = nil }
                .labelStyle(.iconOnly)
                .font(.system(size: 11, weight: .bold))
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(.white.opacity(0.7))
                .padding(8)
        }
    }
}

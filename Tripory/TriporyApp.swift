import SwiftUI
import SwiftData

@main
struct TriporyApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootContainer()
                .tint(.teal)
        }
        .modelContainer(for: [CountryRecord.self, Trip.self, TripStop.self, HomeCountryPeriod.self])
    }
}

struct AppRootContainer: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showLaunchAnimation = true
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage("homeCountryCode") private var homeCountryCode = ""

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some View {
        ZStack {
            RootView()

            // 起動アニメーションが消える瞬間に一瞬アプリ画面が見えてしまわないよう、
            // オンボーディングは(必要な間は)最初から常時マウントしておき、
            // 表示/非表示は不透明度だけで切り替える。
            if homeCountryCode.isEmpty {
                OnboardingView { country in
                    homeCountryCode = country.code
                    modelContext.record(for: country.code).status = .visited
                    modelContext.insert(HomeCountryPeriod(countryCode: country.code))
                }
                .zIndex(2)
                .opacity(showLaunchAnimation ? 0 : 1)
                .allowsHitTesting(!showLaunchAnimation)
            }

            if showLaunchAnimation {
                LaunchAnimationView { showLaunchAnimation = false }
                    .zIndex(3)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = UserDefaults.standard.integer(forKey: "initialTab")
    @State private var showingAddTrip = false
    @State private var searchFocusTrigger = 0
    @AppStorage("homeCountryCode") private var homeCountryCode = ""

    @StateObject private var chrome = ChromeVisibility()

    /// タブのタップは`set`が常に呼ばれるため、既に選択中のタブを再タップしたことを検知できる。
    /// これを使って「検索タブに他のタブから来たときはフォーカスしない、既に検索タブにいて
    /// 再タップしたときだけフォーカスする」という挙動を実現する。
    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == 2 && selectedTab == 2 {
                    searchFocusTrigger += 1
                }
                selectedTab = newValue
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: tabSelection) {
                HomeView(onShowTrips: { withAnimation { selectedTab = 1 } })
                    .tabItem { Label("ホーム", systemImage: "globe.asia.australia.fill") }
                    .tag(0)
                TripTimelineView()
                    .tabItem { Label("旅の記録", systemImage: "calendar") }
                    .tag(1)
                CountryBrowserView(focusTrigger: searchFocusTrigger)
                    .tabItem { Label("国をさがす", systemImage: "magnifyingglass") }
                    .tag(2)
            }

            // 常時表示のフローティング追加ボタン。タブ切り替えで消えたり作り直されたりしないよう
            // TabViewの外側(同じZStack内)に固定で置き、ちらつきを避ける。
            // 表示/非表示は不透明度だけで切り替え、全画面地図などでは隠す。
            Button {
                showingAddTrip = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [.teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 68)
            .opacity(chrome.isFABHidden ? 0 : 1)
            .allowsHitTesting(!chrome.isFABHidden)
        }
        .environmentObject(chrome)
        .sheet(isPresented: $showingAddTrip) {
            TripFormView()
        }
        .task { seedDemoDataIfRequested() }
    }

    /// -seedDemo 起動引数付きのときだけデモデータを投入(開発用)
    private func seedDemoDataIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo"),
              (try? modelContext.fetchCount(FetchDescriptor<CountryRecord>())) == 0
        else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        func setStatus(_ code: String, _ status: CountryStatus) {
            modelContext.record(for: code).status = status
        }

        func addTrip(_ title: String, note: String = "", stops: [(String, String, String?)]) {
            let trip = Trip(title: title, note: note, createdAt: .now)
            modelContext.insert(trip)
            for (index, stop) in stops.enumerated() {
                let (code, startStr, endStr) = stop
                let stopRecord = TripStop(
                    order: index,
                    countryCode: code,
                    startDate: formatter.date(from: startStr) ?? .now,
                    endDate: endStr.flatMap { formatter.date(from: $0) }
                )
                stopRecord.trip = trip
                modelContext.insert(stopRecord)
                let record = modelContext.record(for: code)
                if !record.status.countsAsVisited { record.status = .visited }
            }
        }

        let periodFormatter = DateFormatter()
        periodFormatter.dateFormat = "yyyy-MM-dd"
        modelContext.insert(HomeCountryPeriod(countryCode: "KR", setAt: periodFormatter.date(from: "2015-04-01") ?? .now))
        modelContext.insert(HomeCountryPeriod(countryCode: "JP", setAt: periodFormatter.date(from: "2021-09-01") ?? .now))
        homeCountryCode = "JP"
        setStatus("JP", .visited)
        setStatus("KR", .visited)
        addTrip("ソウル週末旅行", note: "サムギョプサルが最高だった", stops: [("KR", "2024-03-20", nil)])
        addTrip("年末バンコク", stops: [("TH", "2023-12-28", nil)])
        addTrip("GWヨーロッパ周遊", note: "ルーヴルは1日じゃ足りない。ローマ→フィレンツェも巡った。", stops: [
            ("FR", "2019-05-02", "2019-05-07"),
            ("IT", "2019-05-08", "2019-05-10"),
        ])
        addTrip("パリ再訪", stops: [("FR", "2025-10-10", nil)])
        addTrip("NY出張", stops: [("US", "2022-09-15", nil)])
        addTrip("ケアンズでダイビング", stops: [("AU", "2018-08-01", nil)])
        setStatus("IS", .wantToGo)
        setStatus("PE", .wantToGo)
        setStatus("EG", .wantToGo)
    }
}

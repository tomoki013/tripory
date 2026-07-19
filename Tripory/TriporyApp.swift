import SwiftUI
import SwiftData
import MapKit

@main
struct TriporyApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootContainer()
                .tint(.triporyCoral)
        }
        .modelContainer(for: [
            CountryRecord.self,
            Trip.self,
            TripStop.self,
            HomeCountryPeriod.self,
            UserProfile.self,
        ])
    }
}

struct AppRootContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showLaunchAnimation = true
    @State private var forceHideOnboarding = false
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage("homeCountryCode") private var homeCountryCode = ""

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var profile: UserProfile? {
        profiles.first(where: { $0.id == "primary" }) ?? profiles.first
    }

    private var onboardingMode: OnboardingFlowMode? {
        guard !forceHideOnboarding else { return nil }
#if DEBUG
        // デザイン確認用: 完了済みプロフィールでもオンボーディングを強制表示する。
        if ProcessInfo.processInfo.arguments.contains("-qaOnboarding") { return .complete }
#endif
        if homeCountryCode.isEmpty { return .complete }
        if profile?.homeHeroPhotoData == nil { return .photoOnly }
        return nil
    }

    var body: some View {
        ZStack {
            RootView()

            if let profile, let onboardingMode {
                OnboardingFlowView(mode: onboardingMode, profile: profile) {
                    // SwiftDataのクエリ更新を待たず、即座にゲートを閉じる。
                    forceHideOnboarding = true
                }
                .zIndex(2)
                .allowsHitTesting(!showLaunchAnimation)
            }

            if showLaunchAnimation {
                LaunchAnimationView { showLaunchAnimation = false }
                    .zIndex(3)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .task {
            _ = modelContext.primaryUserProfile()
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var selectedDestination: RootDestination = .home
    @State private var showingAddTrip = false
    @State private var revealPayload: NewCountriesRevealPayload?
    @AppStorage("homeCountryCode") private var homeCountryCode = ""

    private var homePhotoData: Data? { profiles.first?.homeHeroPhotoData }

    /// 「+」タップ時にselectedDestinationへ実際に書き込んでしまうと、TabView自身が
    /// 「+」への選択遷移(ハイライトのアニメーション)を一度実行してから、こちらが戻す
    /// 処理をしても間に合わず、一瞬フォーカスが動いて見える。
    /// カスタムBindingのsetterでその場で横取りし、selectedDestinationには一切
    /// 書き込まない(getterも常に実際の値を返す)ことで、TabView側からは
    /// 「+」が選択された事実そのものが観測されないようにする。
    private var tabSelection: Binding<RootDestination> {
        Binding(
            get: { selectedDestination },
            set: { newValue in
                if newValue == .add {
                    showingAddTrip = true
                } else {
                    selectedDestination = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            tab(.home) {
                HomeView(
                    onShowTrips: { select(.trips) },
                    onShowWorld: { select(.world) },
                    onCreateTrip: { showingAddTrip = true }
                )
            }
            tab(.trips) { TripTimelineView() }
            // 「+」はコンテンツを持たない特殊タブ。見た目だけタブバーの他の項目と
            // 並ぶ普通のアイコンにしつつ、色だけコーラルにして区別する。
            // タブバーは通常、選択状態に応じてアイコンをテンプレート塗り替えしてしまう
            // (常に非選択扱いのこのタブは無彩色になる)ため、.paletteレンダリングモードで
            // 明示的に色を固定し、選択状態に関係なく常にコーラルで出るようにする。
            Tab(value: RootDestination.add, content: { Color.clear }) {
                Image(systemName: RootDestination.add.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.triporyCoral)
            }
            tab(.world) { WorldView() }
            tab(.me) { SettingsView(isRoot: true) }
        }
        // タブ切り替えの一瞬、各画面の背景がまだ安全領域まで届いていないコマが
        // 挟まると、ウィンドウの素の背景(黒)がちらつく。TabView自体に控えめな
        // 地色を敷いておき、そのちらつきが黒でなくこの色になるようにする。
        .background(Color.triporyCanvas)
        .sheet(isPresented: $showingAddTrip) {
            TripFormView(presetCountryCode: debugTripFormPreset) { newCountries, totalCount in
                guard !newCountries.isEmpty else { return }
                revealPayload = NewCountriesRevealPayload(countries: newCountries, totalCount: totalCount)
            }
        }
        .fullScreenCover(item: $revealPayload) { payload in
            NewCountriesRevealView(payload: payload, homePhotoData: homePhotoData) {
                revealPayload = nil
                select(.world)
            }
        }
        .task {
            migrateLegacyHomeCountryIfNeeded()
            seedDemoDataIfRequested()
            applyDebugLaunchDestinationIfRequested()
        }
        .task(priority: .utility) {
            // CountryBorders.polygonsByCode(GeoJSONデコード)は実測7.8msで軽微だが、
            // 地球儀タブを開いた瞬間に走らせる意味はないので先に済ませておく。
            _ = CountryBorders.polygonsByCode

            // 本命はこちら: MKMapView + MKImageryMapConfigurationの初回生成は
            // MapKitフレームワーク内部の初期化(mapsdへの接続・シェーダー準備等)を伴い、
            // 実測でmakeUIViewだけで約55ms かかる。これが地球儀タブを開いた瞬間に
            // 初めて発生するため、その一瞬の固まりの主因になっていた。
            // 使い捨てのインスタンスをホーム画面表示から少し経ってバックグラウンドで
            // 先に1つ作っておくと、MapKit側のプロセス内キャッシュが温まり、
            // 実際にタブを開いたときの初回生成が速くなる。
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                let warmup = MKMapView()
                warmup.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            }
        }
    }

    /// 「住んでいる国」履歴(HomeCountryPeriod)が導入される前に homeCountryCode だけ
    /// 設定していたユーザーのために、既存の設定から履歴レコードを1件補完する。
    private func migrateLegacyHomeCountryIfNeeded() {
        guard !homeCountryCode.isEmpty else { return }
        let code = homeCountryCode
        let predicate = #Predicate<HomeCountryPeriod> { $0.countryCode == code }
        let hasPeriodForCurrentCode = ((try? modelContext.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0) > 0
        guard !hasPeriodForCurrentCode else { return }
        modelContext.insert(HomeCountryPeriod(countryCode: homeCountryCode))
        modelContext.record(for: homeCountryCode).status = .visited
        try? modelContext.save()
    }

    private func select(_ destination: RootDestination) {
        selectedDestination = destination
    }

    /// アイコンのみのラベルで標準Tabを作る(タブバーに文字を出さない)。
    private func tab(
        _ destination: RootDestination,
        @ViewBuilder content: () -> some View
    ) -> some TabContent<RootDestination> {
        Tab(value: destination, content: content) {
            Label(destination.label, systemImage: destination.symbol)
                .labelStyle(.iconOnly)
        }
    }

    private func applyDebugLaunchDestinationIfRequested() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-qaTrips") { selectedDestination = .trips }
        if arguments.contains("-qaWorld") { selectedDestination = .world }
        if arguments.contains("-qaMe") { selectedDestination = .me }
        if arguments.contains("-qaTripForm") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingAddTrip = true }
        }
        if arguments.contains("-qaReveal") {
            let countries = ["IS", "PE"].compactMap { CountryCatalog.byCode[$0] }
                .map { NewCountryReveal(country: $0, coverPhotoData: nil) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                revealPayload = NewCountriesRevealPayload(countries: countries, totalCount: 8)
            }
        }
        // -qaTripDetail / -qaCountryDetail はHomeView側で実際のプッシュ遷移として処理する。
#endif
    }

    private var debugTripFormPreset: String? {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-qaTripForm") ? "FR" : nil
#else
        nil
#endif
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

        // 写真主導のUIを確認できるよう、訪問先ごとに色味の違う仮写真を生成して添付する。
        var stubPhotoSeed = 0
        func stubPhoto() -> Data? {
            stubPhotoSeed += 1
            return DemoPhotoFactory.travelPhoto(seed: stubPhotoSeed)
        }

        func addTrip(_ title: String, note: String = "", stops: [(String, String, String?)]) {
            let trip = Trip(title: title, note: note, createdAt: .now)
            modelContext.insert(trip)
            for (index, stop) in stops.enumerated() {
                let (code, startStr, endStr) = stop
                // 複数枚写真のUIをデモで確認できるよう、2〜3枚の仮写真を持たせる。
                let stopRecord = TripStop(
                    order: index,
                    countryCode: code,
                    startDate: formatter.date(from: startStr) ?? .now,
                    endDate: endStr.flatMap { formatter.date(from: $0) },
                    photos: (0..<Int.random(in: 2...3)).compactMap { _ in stubPhoto() }
                )
                stopRecord.trip = trip
                modelContext.insert(stopRecord)
                let record = modelContext.record(for: code)
                if !record.status.countsAsVisited { record.status = .visited }
            }
        }

        let periodFormatter = DateFormatter()
        periodFormatter.dateFormat = "yyyy-MM-dd"
        let profile = modelContext.primaryUserProfile()
        if profile.homeHeroPhotoData == nil {
            profile.homeHeroPhotoData = DemoPhotoFactory.homeHeroPhoto()
            profile.onboardingCompletedAt = .now
        }
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
        try? modelContext.save()
    }
}

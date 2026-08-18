import SwiftUI
import SwiftData
import MapKit

@main
struct TriporyApp: App {
    @State private var purchases = PurchaseManager()
    @State private var consent = ConsentManager()
    @State private var ads = AdsService()
    @State private var tripFlow = TripFlowCoordinator()

    var body: some Scene {
        WindowGroup {
            AppRootContainer()
                .tint(.triporyCoral)
                .environment(purchases)
                .environment(consent)
                .environment(ads)
                .environment(tripFlow)
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
    // オンボーディングを表示するかどうかは起動時に一度だけ決める(computed varにしない)。
    // 以前はhomeCountryCode/profile.homeHeroPhotoDataから毎回計算していたが、
    // オンボーディング中にプロフィールを更新すること自体(例: 写真を選んだ瞬間)が
    // 「オンボーディング不要」の条件を満たしてしまい、「この写真にする」を押す前に
    // オンボーディングごと閉じてアプリ本体が見えてしまう不具合があった。
    @State private var onboardingMode: OnboardingFlowMode?
    @State private var didResolveOnboarding = false
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ConsentManager.self) private var consent
    @Environment(AdsService.self) private var ads

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var profile: UserProfile? {
        profiles.first(where: { $0.id == "primary" }) ?? profiles.first
    }

    var body: some View {
        ZStack {
            RootView()

            if let profile, let onboardingMode {
                OnboardingFlowView(mode: onboardingMode, profile: profile) {
                    self.onboardingMode = nil
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
        // LaunchAnimationView.onFinished()が何らかの理由で呼ばれなかった場合に備えて、
        // 一定時間後に強制的にビューツリーから取り除く(タブバー・追加ボタンが
        // ずっと反応しなくなる不具合の再発防止)。
        .task {
            try? await Task.sleep(for: .seconds(3))
            if showLaunchAnimation { showLaunchAnimation = false }
        }
        .task {
            let profile = modelContext.primaryUserProfile()
            guard onboardingMode == nil else { return }
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                homeCountryCode = "JP"
                didResolveOnboarding = true
                return
            }
            // デザイン確認用: 完了済みプロフィールでもオンボーディングを強制表示する。
            if ProcessInfo.processInfo.arguments.contains("-qaOnboarding") {
                onboardingMode = .complete
                didResolveOnboarding = true
                return
            }
#endif
            if homeCountryCode.isEmpty {
                onboardingMode = .complete
            } else if profile.homeHeroPhotoData == nil {
                onboardingMode = .photoOnly
            }
            didResolveOnboarding = true
        }
        .task(id: didResolveOnboarding && onboardingMode == nil && purchases.entitlementCheckCompleted) {
            guard didResolveOnboarding, onboardingMode == nil, purchases.entitlementCheckCompleted else { return }
#if DEBUG
            guard !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
#endif
            await consent.prepareIfEligible(
                entitlementCheckCompleted: purchases.entitlementCheckCompleted,
                hasRemovedAds: purchases.hasRemovedAds
            )
            await ads.loadInterstitialIfEligible(
                canRequestAds: consent.canRequestAds && consent.mobileAdsInitialized,
                hasRemovedAds: purchases.hasRemovedAds
            )
        }
        .onChange(of: purchases.hasRemovedAds) { _, removed in
            if removed {
                ads.disableAds()
            } else {
                ads.enableAds()
                Task {
                    await consent.prepareIfEligible(
                        entitlementCheckCompleted: purchases.entitlementCheckCompleted,
                        hasRemovedAds: false
                    )
                    await ads.loadInterstitialIfEligible(
                        canRequestAds: consent.canRequestAds && consent.mobileAdsInitialized,
                        hasRemovedAds: false
                    )
                }
            }
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var selectedDestination: RootDestination = .home
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @Environment(TripFlowCoordinator.self) private var tripFlow
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ConsentManager.self) private var consent
    @Environment(AdsService.self) private var ads
    @State private var keyboardVisible = false

    private var homePhotoData: Data? { profiles.first?.homeHeroPhotoData }

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selectedDestination) {
                tab(.home) {
                    HomeView(
                        onShowTrips: { select(.trips) },
                        onShowWorld: { select(.world) },
                        onCreateTrip: { tripFlow.presentNewTrip() }
                    )
                }
                tab(.trips) { TripTimelineView() }
                tab(.world) { WorldView() }
                tab(.me) { SettingsView(isRoot: true) }
            }
            // タブ切り替えの一瞬、各画面の背景がまだ安全領域まで届いていないコマが
            // 挟まると、ウィンドウの素の背景(黒)がちらつく。TabView自体に控えめな
            // 地色を敷いておき、そのちらつきが黒でなくこの色になるようにする。
            .background(Color.triporyCanvas)
            // iOS26のフローティング(Liquid Glass)タブバーは、システムのオーバーレイ
            // として画面最前面に描画されるため、`.safeAreaInset(edge: .bottom)`で
            // 積んだコンテンツはタブバーの"上"ではなく"背後"に回り込み、タブバーと
            // 重なって見える(以前の固定値61ptの見積もりに代わり導入したが、
            // フローティングタブバー特有のこの問題までは解消しなかった)。
            // `.tabViewBottomAccessory`はこのタブバーと共存するために導入された
            // 標準APIで、タブバーの実際の高さ・形に関わらずその直上に正しく
            // 積み重ねてくれる。
            .tabViewBottomAccessory {
                if !keyboardVisible && !consent.isPresentingForm && !ads.isPresentingInterstitial {
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Button {
                                tripFlow.presentNewTrip()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2.weight(.semibold))
                                    .frame(width: 56, height: 56)
                                    .foregroundStyle(.white)
                                    .background(Color.triporyCoral, in: Circle())
                                    .shadow(color: Color.triporyNavy.opacity(0.25), radius: 10, y: 4)
                            }
                            .accessibilityLabel("旅を記録する")
                            .accessibilityIdentifier("rootAddTripButton")
                            .padding(.trailing, 18)
                        }
                        if selectedDestination != .me {
                            RootBannerAd(width: geometry.size.width)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .sheet(item: Binding(get: { tripFlow.addRequest }, set: { tripFlow.addRequest = $0 })) { request in
            TripFormView(presetCountryCode: request.presetCountryCode ?? debugTripFormPreset)
        }
        .fullScreenCover(item: Binding(get: { tripFlow.revealPayload }, set: { tripFlow.revealPayload = $0 })) { payload in
            NewCountriesRevealView(payload: payload, homePhotoData: homePhotoData) {
                let result = tripFlow.completeReveal()
                select(.world)
                if let result {
                    ads.presentIfEligible(
                        eventID: result.eventID,
                        newlyVisitedCountryCodes: result.newlyVisitedCountryCodes,
                        canRequestAds: consent.canRequestAds && consent.mobileAdsInitialized,
                        hasRemovedAds: purchases.hasRemovedAds
                    )
                    Task {
                        await ads.loadInterstitialIfEligible(
                            canRequestAds: consent.canRequestAds && consent.mobileAdsInitialized,
                            hasRemovedAds: purchases.hasRemovedAds
                        )
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
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
                .accessibilityIdentifier("tab-\(destination.identifierSuffix)")
        }
    }

    private func applyDebugLaunchDestinationIfRequested() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-qaTrips") { selectedDestination = .trips }
        if arguments.contains("-qaWorld") { selectedDestination = .world }
        if arguments.contains("-qaMe") { selectedDestination = .me }
        if arguments.contains("-qaTripForm") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { tripFlow.presentNewTrip(presetCountryCode: "FR") }
        }
        if arguments.contains("-qaReveal") {
            let countries = ["IS", "PE"].compactMap { CountryCatalog.byCode[$0] }
                .map { NewCountryReveal(country: $0, coverPhotoData: nil) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                tripFlow.revealPayload = NewCountriesRevealPayload(countries: countries, totalCount: 8)
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

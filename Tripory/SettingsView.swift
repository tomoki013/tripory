import SwiftUI
import SwiftData
import PhotosUI

/// マイページ = ホーム/国一覧と同じトーンの、ダークヒーロー+クリーム地カード構成。
struct SettingsView: View {
    var isRoot = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ConsentManager.self) private var consent
    @Query private var records: [CountryRecord]
    @Query private var trips: [Trip]
    @Query private var profiles: [UserProfile]
    @State private var showingResetConfirm = false
    @State private var showingHomeCountryPicker = false
    @State private var confirmingHomeCountry: Country?
    @State private var showingHomePhotoEditor = false
    @State private var showingFAQDirectly = false
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage("homeCountryCode") private var homeCountryCode = ""

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var homeCountry: Country? { CountryCatalog.byCode[homeCountryCode] }
    private var profile: UserProfile? { profiles.first(where: { $0.id == "primary" }) ?? profiles.first }

    // ホームと国数の数え方を統一する(住んでいる国も1か国として数える)。
    private var visitedCount: Int { records.filter { $0.status.countsAsVisited }.count }
    private var wantToGoCount: Int { records.filter { $0.status == .wantToGo }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero

                    VStack(alignment: .leading, spacing: 14) {
                        statsRow
                        settingsCard
                        removeAdsCard
                        supportCard
                        cheerCard
                        aboutCard
                        dangerCard
                        developerCard
                    }
                    .padding(.horizontal, 18)

                    Text(verbatim: "© 2026 Tripory")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
                // 右下に浮かぶ追加ボタンの分、最後のカードが隠れないよう余白を確保する。
                .padding(.bottom, 90)
            }
            // heroに.ignoresSafeArea()が付いていなかったため、ステータスバー分の隙間が
            // ウィンドウの素の背景(黒)のまま見えてしまっていた。ScrollView自体を
            // 上端の安全領域を無視させることで、heroが画面本当の一番上まで届くようにする。
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
            .background(Color.triporyCanvas)
            .hidesNavigationBar()
            .overlay(alignment: .topTrailing) {
                if !isRoot {
                    CircleGlassButton(systemImage: "xmark", label: "閉じる") { dismiss() }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                }
            }
            .alert("すべてのデータを削除しますか?", isPresented: $showingResetConfirm) {
                Button("削除する", role: .destructive) { resetAllData() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("国のステータスと旅の記録がすべて削除されます。")
            }
            .sheet(isPresented: $showingHomeCountryPicker) {
                CountryPickerView(
                    onSelect: { country in confirmingHomeCountry = country },
                    disablingCode: homeCountryCode
                )
            }
            .sheet(item: $confirmingHomeCountry) { country in
                ConfirmHomeCountryView(
                    country: country,
                    onConfirm: {
                        homeCountryCode = country.code
                        modelContext.record(for: country.code).status = .visited
                        modelContext.insert(HomeCountryPeriod(countryCode: country.code))
                        confirmingHomeCountry = nil
                    },
                    onReselect: {
                        confirmingHomeCountry = nil
                        showingHomeCountryPicker = true
                    }
                )
            }
            .sheet(isPresented: $showingHomePhotoEditor) {
                if let profile {
                    HomePhotoEditorSheet(profile: profile)
                }
            }
            .navigationDestination(isPresented: $showingFAQDirectly) { FAQView() }
#if DEBUG
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-qaFAQ") else { return }
                try? await Task.sleep(for: .seconds(1))
                showingFAQDirectly = true
            }
#endif
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            if let profile {
                HomeHeroCropView(profile: profile)
            } else {
                PhotoPlaceholderView(symbol: "photo", title: "マイワールド")
            }
            LinearGradient(colors: [.clear, Color.triporyPhotoOverlay.opacity(0.94)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("マイワールド")
                        .font(.caption.weight(.black))
                        .tracking(3)
                        .foregroundStyle(Color.triporyCoral)
                    BrandSparkle(size: 10)
                }
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(visitedCount)")
                        .font(TriporyTypography.brandNumber(42))
                        .foregroundStyle(Color.triporyCoral)
                    Text("か国")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.triporyGold)
                }
                if let homeCountry {
                    Text("\(homeCountry.name)から始まる、あなたの世界。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }

                Button("写真を変更", systemImage: "photo.badge.plus") {
                    showingHomePhotoEditor = true
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .font(.caption.weight(.semibold))
                .tint(.white)
                .disabled(profile == nil)
                .padding(.top, 6)
            }
            .foregroundStyle(.white)
            .padding(22)
            .padding(.top, 40)
        }
        .frame(height: 300)
        .clipped()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: "\(visitedCount)", label: "行った国")
            statTile(value: "\(wantToGoCount)", label: "行きたい国")
            statTile(value: "\(trips.count)", label: "旅の記録")
        }
    }

    private func statTile(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title, design: .serif, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.triporyInk)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Settings card (home country / appearance / language)

    private var settingsCard: some View {
        card(title: "設定") {
            settingsRow {
                showingHomeCountryPicker = true
            } content: {
                HStack {
                    Text("住んでいる国").foregroundStyle(Color.triporyInk)
                    Spacer()
                    if let homeCountry {
                        Text(homeCountry.flag)
                        Text(homeCountry.name).foregroundStyle(.secondary)
                    } else {
                        Text("未設定").foregroundStyle(.secondary)
                    }
                    chevron
                }
            }
            Text("海外旅行の記録から、住んでいる国を除くために使います。過去に設定していた国は「旅の記録」ページで確認できます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            divider

            HStack {
                Text("外観").foregroundStyle(Color.triporyInk)
                Spacer()
                Picker(selection: $appearanceModeRaw) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                } label: { EmptyView() }
                .pickerStyle(.menu)
                .tint(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            divider

            settingsRow {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            } content: {
                HStack {
                    Text("言語").foregroundStyle(Color.triporyInk)
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Support card

    private var supportCard: some View {
        card(title: "サポート") {
            settingsRow {
                openURL(AppLinks.support)
            } content: {
                externalRow("お問い合わせ・不具合報告")
            }
            divider
            NavigationLink {
                FAQView()
            } label: {
                HStack {
                    Text("よくある質問").foregroundStyle(Color.triporyInk)
                    Spacer()
                    chevron
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Cheer card

    private var cheerCard: some View {
        card(title: "このアプリを応援する") {
            if let reviewURL = AppLinks.reviewURL {
                settingsRow {
                    openURL(reviewURL)
                } content: {
                    externalRow("App Storeで評価する")
                }
                divider
            }
            ShareLink(item: shareURL, message: Text(shareMessage)) {
                HStack {
                    Text("このアプリを友達にシェアする").foregroundStyle(Color.triporyInk)
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - About / legal / developer / version

    private var aboutCard: some View {
        card(title: "このアプリについて") {
            NavigationLink {
                LegalTextView(title: "プライバシーポリシー", bodyText: LegalText.privacyPolicy, webURL: LegalText.privacyPolicyURL)
            } label: {
                legalRow("プライバシーポリシー")
            }
            divider
            NavigationLink {
                LegalTextView(title: "利用規約", bodyText: LegalText.termsOfService, webURL: LegalText.termsOfServiceURL)
            } label: {
                legalRow("利用規約")
            }

            divider

            HStack {
                Text("バージョン").foregroundStyle(Color.triporyInk)
                Spacer()
                Text(appVersion).foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Developer card

    /// 以前は「このアプリについて」カードの中、法的文書とバージョン番号の間に
    /// 名前だけ大きく挟まっていて浮いていた。ほかの項目と同じ「card(title:)」の
    /// 形式に載せ替えて、他の設定項目と並んでも違和感のない1つのセクションにする。
    /// コピーライトは「アプリ自体にかかるもの」であり開発者個人にかかるものではないため、
    /// このカードには含めず、カード列の外(一番下)に単独で置く。
    private var developerCard: some View {
        card(title: "開発者") {
            HStack(spacing: 12) {
                AppIconThumbnail(size: 36)
                Text(verbatim: "Tomokichi")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.triporyInk)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            divider

            settingsRow {
                openURL(AppLinks.brand)
            } content: {
                externalRow("Tripory Webサイト")
            }

            divider

            settingsRow {
                openURL(URL(string: "https://tmkch.io")!)
            } content: {
                externalRow("その他のアプリ")
            }
        }
    }

    private var dangerCard: some View {
        VStack(spacing: 8) {
            Button(role: .destructive) {
                showingResetConfirm = true
            } label: {
                Text("すべてのデータを削除")
                    .font(.subheadline.weight(.semibold))
                    .underline()
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            Text("国のステータスと旅の記録をすべて削除します。この操作は取り消せません。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Card building blocks

    private func card(title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.bold())
                .triporyTracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func settingsRow(action: @escaping () -> Void, @ViewBuilder content: () -> some View) -> some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.triporyInk)
    }

    private func externalRow(_ titleKey: LocalizedStringKey) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            Image(systemName: "arrow.up.forward")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func legalRow(_ titleKey: LocalizedStringKey) -> some View {
        HStack {
            Text(titleKey).foregroundStyle(Color.triporyInk)
            Spacer()
            chevron
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    private var divider: some View {
        Divider().padding(.leading, 14)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var shareURL: URL {
        AppLinks.brand
    }

    private var shareMessage: String {
        String(localized: "行った国を記録できるアプリ「Tripory」を使ってみて!")
    }

    private func resetAllData() {
        for trip in trips { modelContext.delete(trip) }
        for record in records { modelContext.delete(record) }

        // 住んでいる国は旅の記録ではなく設定なので、全データ削除後も訪問済みのまま保つ
        if !homeCountryCode.isEmpty {
            modelContext.record(for: homeCountryCode).status = .visited
        }
    }

    private var removeAdsCard: some View {
        card(title: "広告") {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    purchases.hasRemovedAds ? "広告削除済み" : "広告を削除",
                    systemImage: purchases.hasRemovedAds ? "checkmark.seal.fill" : "rectangle.slash"
                )
                .font(.headline)
                .foregroundStyle(purchases.hasRemovedAds ? Color.triporyCoral : Color.triporyInk)
                .accessibilityIdentifier("removeAdsStatus")

                Text(purchases.hasRemovedAds
                     ? "このApple Accountではバナー広告と全画面広告が表示されません。"
                     : "一度購入すれば、同じApple Accountで永久に広告が表示されなくなります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !purchases.hasRemovedAds {
                    Button {
                        Task { await purchases.purchase() }
                    } label: {
                        HStack {
                            Text("広告を削除")
                            Spacer()
                            if purchases.isLoading {
                                ProgressView()
                            } else if let price = purchases.product?.displayPrice {
                                Text(price).fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(Color.triporyCoral)
                    .disabled(purchases.isLoading || purchases.product == nil)
                    .accessibilityHint("Appleの購入画面を開きます")
                }

                Button("購入を復元") {
                    Task { await purchases.restore() }
                }
                .disabled(purchases.isLoading)
                .accessibilityIdentifier("restorePurchaseButton")

                if consent.privacyOptionsRequired && !purchases.hasRemovedAds {
                    Divider()
                    Button("プライバシー設定", systemImage: "hand.raised") {
                        Task { await consent.presentPrivacyOptions() }
                    }
                }

                if let message = purchases.statusMessage {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityLabel(message)
                }
                if let error = purchases.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityLabel("エラー、\(error)")
                }
            }
            .padding(16)
        }
    }
}

private struct HomePhotoEditorSheet: View {
    let profile: UserProfile
    private let originalPhotoData: Data?
    private let originalFocalX: Double
    private let originalFocalY: Double
    private let originalScale: Double

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var availableSize = CGSize(width: 390, height: 844)

    // 画面横幅からVStackの左右padding(24pt×2)を引いた、プレビューが実際に使える幅。
    private var cropPreviewSize: CGSize {
        homeHeroPreviewSize(
            maxWidth: max(availableSize.width - 48, 1),
            maxHeight: 420,
            availableSize: availableSize
        )
    }

    init(profile: UserProfile) {
        self.profile = profile
        originalPhotoData = profile.homeHeroPhotoData
        originalFocalX = profile.homeHeroFocalX
        originalFocalY = profile.homeHeroFocalY
        originalScale = profile.homeHeroScale
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.triporyNavy.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("ホームの主役になる一枚")
                            .font(.system(.largeTitle, design: .serif, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("ドラッグして位置を調整し、ピンチで拡大できます。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))

                        // ホームの写真は画面いっぱい(フルスクリーンの縦横比)に表示される。
                        // ここでのプレビューが正方形に近い比率のままだと、ここで良い位置に
                        // 合わせても実際のホームでは全然違う場所が切り取られてしまう。
                        // プレビューの比率を実機の画面比率に合わせて、見たままになるようにする。
                        HomeHeroCropView(profile: profile, isInteractive: true)
                            .frame(width: cropPreviewSize.width, height: cropPreviewSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.62), lineWidth: 1.5))
                            .frame(maxWidth: .infinity)

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Color.triporyGold)
                        }

                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Text("別の写真を選ぶ")
                                .font(.headline)
                                .foregroundStyle(Color.triporyNavy)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .overlay {
                            if isLoading { ProgressView().tint(Color.triporyNavy) }
                        }

                        PrimaryCapsuleButton(
                            title: "この写真にする",
                            style: .coral,
                            isEnabled: profile.homeHeroPhotoData != nil && !isLoading,
                            action: confirm
                        )
                    }
                    .padding(24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("ホーム写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.triporyNavy, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: cancel)
                }
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: pickerItem) { _, item in
            Task { await load(item) }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { availableSize = proxy.size }
                    .onChange(of: proxy.size) { _, size in availableSize = size }
            }
        }
    }

    @MainActor
    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let compressed = ImageCompression.compress(data)
            else {
                errorMessage = String(localized: "写真を読み込めませんでした。別の写真を選んでください。")
                return
            }
            profile.homeHeroPhotoData = compressed
            profile.homeHeroFocalX = 0.5
            profile.homeHeroFocalY = 0.5
            profile.homeHeroScale = 1
        } catch {
            errorMessage = String(localized: "写真を読み込めませんでした。もう一度お試しください。")
        }
    }

    private func confirm() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancel() {
        profile.homeHeroPhotoData = originalPhotoData
        profile.homeHeroFocalX = originalFocalX
        profile.homeHeroFocalY = originalFocalY
        profile.homeHeroScale = originalScale
        dismiss()
    }
}

private struct LegalTextView: View {
    let title: String
    let bodyText: String
    let webURL: URL

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    openURL(webURL)
                } label: {
                    Label("Webで見る", systemImage: "safari")
                        .font(.subheadline.bold())
                }

                Text(bodyText)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FAQView: View {
    private struct Item: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }

    private struct Category: Identifiable {
        let id = UUID()
        let title: LocalizedStringKey
        let symbol: String
        let items: [Item]
    }

    // カテゴリ分けなしの1本のリストだと、探している1問にたどり着くまで延々スクロールする
    // ことになっていた。「プライバシー」「使い方」で分け、設定画面のほかのカード(card(title:))
    // と同じ見た目に揃えることで、この画面だけ浮いていた素っ気なさを解消する。
    private let categories: [Category] = [
        Category(title: "プライバシーとデータ", symbol: "lock.shield", items: [
            Item(question: String(localized: "データはどこに保存されますか?"), answer: String(localized: "すべて端末内に保存されます。外部のサーバーには送信されません。")),
            Item(question: String(localized: "オフラインでも使えますか?"), answer: String(localized: "はい。地図の表示にのみインターネット接続が必要です。")),
            Item(question: String(localized: "写真を追加すると、写真ライブラリ全体を見られてしまいますか?"), answer: String(localized: "いいえ。iOSの写真選択画面で選んだ写真だけがこのアプリに渡され、ライブラリ全体へはアクセスしません。そのためアクセス許可の確認も表示されません。")),
            Item(question: String(localized: "機種変更したらデータはどうなりますか?"), answer: String(localized: "データは端末内のみの保存のため、バックアップや引き継ぎ機能は現在ありません。機種変更前に画面を記録するなどしてご注意ください。")),
        ]),
        Category(title: "使い方", symbol: "questionmark.circle", items: [
            Item(question: String(localized: "住んでいる国は何のためにありますか?"), answer: String(localized: "海外旅行の記録から、住んでいる国を除くために使います。設定した国は自動的に「訪問済み」になり、行き先の候補からは外れます。")),
            Item(question: String(localized: "住んでいる国はあとから変更できますか?"), answer: String(localized: "はい。設定の「住んでいる国」からいつでも変更できます。過去に設定していた国は「旅の記録」ページの「住んでいた国」から矢印で辿って確認でき、必要であれば訪問済みの扱いを取り消すこともできます。")),
            Item(question: String(localized: "行きたい国に旅の記録をつけるとどうなりますか?"), answer: String(localized: "自動的に「訪問済み」に切り替わり、行きたい国の一覧からは外れます。")),
            Item(question: String(localized: "行きたい国にメモは残せますか?"), answer: String(localized: "はい。国の詳細ページの「なぜ行きたい?」欄に自由に書き残せます。")),
            Item(question: String(localized: "地球儀・平面地図・コレクションの違いは?"), answer: String(localized: "国一覧タブの右上のボタンで切り替えられる3つの見え方です。地球儀は宇宙から見た3D表示、平面地図は従来の地図に近い平面表示、コレクションは訪れた国をカードで一覧できる表示です。どれも同じ記録を違う形で見ているだけで、記録自体はどの表示でも変わりません。")),
            Item(question: String(localized: "記録を間違えてしまいました。修正できますか?"), answer: String(localized: "はい。国の詳細ページやそれぞれの旅の記録ページから、いつでも編集・削除できます。")),
        ]),
    ]

    @State private var expandedID: Item.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("よくある質問")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.triporyInk)
                    Text("気になることがあれば、まずはこちらをご確認ください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(categories) { category in
                    categoryCard(category)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Color.triporyCanvas)
        .navigationTitle("よくある質問")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func categoryCard(_ category: Category) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(category.title, systemImage: category.symbol)
                .font(.caption.bold())
                .triporyTracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    faqRow(item)
                    if index < category.items.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func faqRow(_ item: Item) -> some View {
        let isExpanded = expandedID == item.id
        return VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    expandedID = isExpanded ? nil : item.id
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.question)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.triporyInk)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.triporyCoral)
                        .rotationEffect(.degrees(isExpanded ? 45 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

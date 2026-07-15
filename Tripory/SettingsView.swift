import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [CountryRecord]
    @Query private var trips: [Trip]
    @State private var showingResetConfirm = false
    @State private var showingHomeCountryPicker = false
    @State private var confirmingHomeCountry: Country?
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage("homeCountryCode") private var homeCountryCode = ""

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var homeCountry: Country? { CountryCatalog.byCode[homeCountryCode] }

    private var visitedCount: Int { records.filter { $0.status.countsAsVisited }.count }
    private var wantToGoCount: Int { records.filter { $0.status == .wantToGo }.count }

    var body: some View {
        NavigationStack {
            List {
                headerSection

                Section {
                    Button {
                        showingHomeCountryPicker = true
                    } label: {
                        HStack {
                            Text("住んでいる国")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let homeCountry {
                                Text(homeCountry.flag)
                                Text(homeCountry.name)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("未設定")
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } footer: {
                    Text("海外旅行の記録から、住んでいる国を除くために使います。過去に設定していた国は「旅の記録」ページで確認できます。")
                }

                Section("あなたの記録") {
                    LabeledContent("行った国") { Text("\(visitedCount) / \(CountryCatalog.totalCount)") }
                    LabeledContent("行きたい国") { Text("\(wantToGoCount)") }
                    LabeledContent("旅の記録") { Text("\(trips.count)") }
                }

                aboutSection

                Section {
                    Picker(selection: $appearanceModeRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    } label: {
                        Text("外観")
                    }
                    externalLinkButton("言語") {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                } footer: {
                    Text("言語は端末の「設定」アプリ内、このアプリのページから変更できます。")
                }

                Section("サポート") {
                    externalLinkButton("バグ・不具合報告") {
                        openURL(mailURL(subject: "【不具合報告】Tripory"))
                    }
                    externalLinkButton("ご意見・ご要望を送る") {
                        openURL(mailURL(subject: "【ご意見・ご要望】Tripory"))
                    }
                    NavigationLink {
                        FAQView()
                    } label: {
                        Text("よくある質問")
                    }
                }

                Section("このアプリを応援する") {
                    externalLinkButton("App Storeで評価する") {
                        openURL(appStoreReviewURL)
                    }
                    ShareLink(item: shareURL, message: Text(shareMessage)) {
                        Text("このアプリを友達にシェアする")
                    }
                }

                Section("法的情報") {
                    NavigationLink {
                        LegalTextView(title: "プライバシーポリシー", bodyText: LegalText.privacyPolicy, webURL: LegalText.privacyPolicyURL)
                    } label: {
                        Text("プライバシーポリシー")
                    }
                    NavigationLink {
                        LegalTextView(title: "利用規約", bodyText: LegalText.termsOfService, webURL: LegalText.termsOfServiceURL)
                    } label: {
                        Text("利用規約")
                    }
                }

                developerSection

                Section {
                    LabeledContent("バージョン", value: appVersion)
                }

                Section {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Text("すべてのデータを削除")
                    }
                } footer: {
                    Text("国のステータスと旅の記録をすべて削除します。この操作は取り消せません。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
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
        }
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [.teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Tripory")
                    .font(.title3.bold())
                Text("これまでの旅を、世界地図に。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("旅単位で訪れた国と写真を記録できるアプリ")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
        }
    }

    private var aboutSection: some View {
        Section("このアプリについて") {
            Text("データは端末内にのみ保存されます")
            Text("アカウント登録・通信は不要です")
            Text("写真は選んだものだけがこのアプリに渡り、ライブラリ全体は見ません")
            Text("国境データ: Natural Earth (Public Domain)")
        }
    }

    private var developerSection: some View {
        Section {
            Text("Tomokichi")
            externalLinkButton("Webサイト") {
                openURL(URL(string: "https://tomokichi.dev")!)
            }
            externalLinkButton("その他のアプリ") {
                openURL(URL(string: "https://tmkch.io")!)
            }
        } header: {
            Text("開発者")
        } footer: {
            Text("© 2026 Tomokichi")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    /// 端末を離れて外部サイト・アプリへ移動する行。矢印アイコンでそれとわかるようにする。
    private func externalLinkButton(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(titleKey)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func mailURL(subject: String) -> URL {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:support@tripory-app.example?subject=\(encodedSubject)")!
    }

    /// TODO: 公開後、実際のApp Store IDに差し替える
    private var appStoreReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id0000000000?action=write-review")!
    }

    /// TODO: 公開後、実際のApp StoreリンクをshareURLに差し替える
    private var shareURL: URL {
        URL(string: "https://tomokichi.dev")!
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
    private let items: [(String, String)] = [
        (String(localized: "データはどこに保存されますか?"), String(localized: "すべて端末内に保存されます。外部のサーバーには送信されません。")),
        (String(localized: "オフラインでも使えますか?"), String(localized: "はい。地図の表示にのみインターネット接続が必要です。")),
        (String(localized: "写真を追加すると、写真ライブラリ全体を見られてしまいますか?"), String(localized: "いいえ。iOSの写真選択画面で選んだ写真だけがこのアプリに渡され、ライブラリ全体へはアクセスしません。そのためアクセス許可の確認も表示されません。")),
        (String(localized: "住んでいる国は何のためにありますか?"), String(localized: "海外旅行の記録から、住んでいる国を除くために使います。設定した国は自動的に「訪問済み」になり、行き先の候補からは外れます。")),
        (String(localized: "住んでいる国はあとから変更できますか?"), String(localized: "はい。設定の「住んでいる国」からいつでも変更できます。過去に設定していた国は「旅の記録」ページの「住んでいる国」から矢印で辿って確認でき、必要であれば訪問済みの扱いを取り消すこともできます。")),
        (String(localized: "行きたい国に旅の記録をつけるとどうなりますか?"), String(localized: "自動的に「訪問済み」に切り替わり、行きたい国の一覧からは外れます。")),
        (String(localized: "行きたい国にメモは残せますか?"), String(localized: "はい。国の詳細ページの「なぜ行きたい?」欄に自由に書き残せます。")),
        (String(localized: "白黒モードとは何ですか?"), String(localized: "地図の地形や海の色を控えめにし、すべての国の輪郭を黒線で示す表示モードです。記録した国だけに色がつき、塗り絵帳のように楽しめます。ホーム画面の地図上で切り替えられます。")),
        (String(localized: "機種変更したらデータはどうなりますか?"), String(localized: "データは端末内のみの保存のため、バックアップや引き継ぎ機能は現在ありません。機種変更前に画面を記録するなどしてご注意ください。")),
        (String(localized: "記録を間違えてしまいました。修正できますか?"), String(localized: "はい。国の詳細ページやそれぞれの旅の記録ページから、いつでも編集・削除できます。")),
    ]

    var body: some View {
        List {
            ForEach(items, id: \.0) { question, answer in
                VStack(alignment: .leading, spacing: 6) {
                    Text(question)
                        .font(.subheadline.bold())
                    Text(answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("よくある質問")
        .navigationBarTitleDisplayMode(.inline)
    }
}

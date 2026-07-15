import SwiftUI
import SwiftData

/// 全197か国を検索・閲覧する画面。ホームの検索アイコンから開く。
/// 「行きたい国」の登録や、旅を作らずに国のページへ直接アクセスするための動線。
struct CountryBrowserView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all, visited, wantToGo, unvisited
        var id: String { rawValue }

        var displayLabel: String {
            switch self {
            case .all: return String(localized: "すべて")
            case .visited: return String(localized: "行った")
            case .wantToGo: return String(localized: "行きたい")
            case .unvisited: return String(localized: "未訪問")
            }
        }
    }

    var focusTrigger = 0

    @Environment(\.modelContext) private var modelContext
    @Query private var records: [CountryRecord]
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var randomPick: Country?
    @State private var isRolling = false
    @State private var showingSettings = false
    @FocusState private var isSearchFocused: Bool

    private var statusByCode: [String: CountryStatus] {
        Dictionary(uniqueKeysWithValues: records.map { ($0.code, $0.status) })
    }

    /// 住んでいる国は「行き先を探す」対象ではないので一覧から除く
    private var browsableCountries: [Country] {
        CountryCatalog.all.filter { $0.code != homeCountryCode }
    }

    private func count(for filter: Filter, browsable: [Country], statusByCode: [String: CountryStatus]) -> Int {
        switch filter {
        case .all: return browsable.count
        case .visited: return browsable.filter { (statusByCode[$0.code] ?? .none).countsAsVisited }.count
        case .wantToGo: return browsable.filter { (statusByCode[$0.code] ?? .none) == .wantToGo }.count
        case .unvisited: return browsable.filter { (statusByCode[$0.code] ?? .none) == .none }.count
        }
    }

    private func matches(_ country: Country, statusByCode: [String: CountryStatus]) -> Bool {
        guard country.code != homeCountryCode else { return false }
        let status = statusByCode[country.code] ?? .none
        switch filter {
        case .all: break
        case .visited: guard status.countsAsVisited else { return false }
        case .wantToGo: guard status == .wantToGo else { return false }
        case .unvisited: guard status == .none else { return false }
        }
        guard !searchText.isEmpty else { return true }
        return country.name.localizedStandardContains(searchText)
            || country.code.localizedStandardContains(searchText)
    }

    var body: some View {
        // 計算プロパティを複数回参照するとその都度O(n)で再構築されるため、
        // このbody評価内で使う分は1回だけ計算して使い回す。
        let statusByCode = statusByCode
        let browsable = browsableCountries

        return NavigationStack {
            List {
                ForEach(Continent.allCases) { continent in
                    let countries = CountryCatalog.countries(in: continent).filter { matches($0, statusByCode: statusByCode) }
                    if !countries.isEmpty {
                        Section {
                            ForEach(countries) { country in
                                NavigationLink(value: country) {
                                    CountryRow(country: country, status: statusByCode[country.code] ?? .none)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        setStatus(.wantToGo, for: country)
                                    } label: {
                                        Label("行きたい", systemImage: "star.fill")
                                    }
                                    .tint(.orange)
                                }
                            }
                        } header: {
                            Label(continent.displayName, systemImage: continent.symbolName)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("国をさがす")
            .toolbar { SettingsBarButton(isPresented: $showingSettings) }
            .searchable(text: $searchText, prompt: "国名で検索")
            .modifier(SearchAutoFocusModifier(focusTrigger: focusTrigger, isFocused: $isSearchFocused))
            .navigationDestination(for: Country.self) { country in
                CountryDetailView(country: country)
            }
            .navigationDestination(item: $randomPick) { country in
                CountryDetailView(country: country)
            }
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 10) {
                    randomDestinationButton
                    Picker("絞り込み", selection: $filter) {
                        ForEach(Filter.allCases) { f in
                            Text("\(f.displayLabel) \(count(for: f, browsable: browsable, statusByCode: statusByCode))").tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                .background(.bar)
            }
        }
    }

    private var randomDestinationButton: some View {
        Button(action: rollRandomDestination) {
            HStack(spacing: 8) {
                Image(systemName: "dice.fill")
                    .rotationEffect(.degrees(isRolling ? 360 : 0))
                Text("次はどこ行く?ランダムに1か国選ぶ")
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }

    private func setStatus(_ status: CountryStatus, for country: Country) {
        withAnimation {
            modelContext.record(for: country.code).status = status
        }
    }

    private func rollRandomDestination() {
        let statusByCode = statusByCode
        let browsable = browsableCountries
        let undiscovered = browsable.filter { (statusByCode[$0.code] ?? .none) == .none }
        let pool = undiscovered.isEmpty
            ? browsable.filter { (statusByCode[$0.code] ?? .none) == .wantToGo }
            : undiscovered
        guard let pick = pool.randomElement() else { return }

        withAnimation(.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true)) {
            isRolling.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            randomPick = pick
        }
    }
}

/// iOS 18+では、既に検索タブにいる状態でタブを再タップしたときだけ検索欄に自動フォーカスする。
/// 他のタブから検索タブに切り替えてきたときはフォーカスしない。iOS 17では`searchFocused`が使えないため何もしない。
private struct SearchAutoFocusModifier: ViewModifier {
    let focusTrigger: Int
    var isFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .searchFocused(isFocused)
                .onChange(of: focusTrigger) { _, _ in
                    isFocused.wrappedValue = true
                }
        } else {
            content
        }
    }
}

struct CountryRow: View {
    let country: Country
    let status: CountryStatus

    var body: some View {
        HStack(spacing: 14) {
            Text(country.flag)
                .font(.system(size: 30))
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.05), in: Circle())

            Text(country.name)

            Spacer()

            if status != .none {
                Text(status.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

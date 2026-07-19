import SwiftUI
import SwiftData

/// 旅の詳細 = ダークネイビー全面。ヒーロー写真 → タイトル → 国の円形サムネイル →
/// 旅のハイライト → 旅のメモ → 訪問の記録、右下に編集ペンのフローティングボタン。
struct TripDetailView: View {
    let trip: Trip

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TripStop.startDate) private var allStops: [TripStop]
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    private var heroPhotoData: Data? {
        trip.heroPhotoData ?? trip.sortedStops.flatMap(\.photos).first
    }

    private var highlightPhotos: [Data] {
        trip.sortedStops.flatMap(\.photos)
    }

    var body: some View {
        // GeometryReaderで実測した画面幅を子孫全員に明示的な絶対値として渡す。
        // `.frame(maxWidth: .infinity)` は「これ以上は広がってよい」という柔軟な制約でしかなく、
        // 深くネストした子(Text/HStackなど)が理想サイズを主張すると突破されページごと横に動く。
        // 絶対値の `.frame(width:)` で物理的に画面幅を超えられなくする。
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero
                        VStack(alignment: .leading, spacing: 28) {
                            titleBlock
                            collectedCountries
                            if !highlightPhotos.isEmpty { highlights }
                            if !trip.note.isEmpty { noteSection }
                            visitHistory
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        // 右下に浮かぶ追加ボタンの分、訪問の記録リストの最後の項目が隠れないよう余白を確保する。
                        .padding(.bottom, 110)
                    }
                    // 固定幅を与えるのはここ1箇所だけにする。内側にも`.frame(width:)`を
                    // 重ねると、後から付けた`.padding`がその固定幅の外側に加算されてしまい、
                    // 合計幅が画面より広くなって左右にはみ出す(左の余白が消えて右に隙間ができる)。
                    .frame(width: proxy.size.width, alignment: .leading)
                }
                .ignoresSafeArea(edges: .top)
                .scrollIndicators(.hidden)

                topControls
            }
        }
        .background(Color.triporyNavy.ignoresSafeArea())
        .hidesNavigationBar()
        .swipeToGoBack()
        // preferredColorSchemeはシーン全体へ伝播してしまうため、この画面配下だけダークにする。
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showingEdit) {
            TripFormView(editingTrip: trip)
        }
        .alert("この旅を削除しますか?", isPresented: $showingDeleteConfirm) {
            Button("削除する", role: .destructive) { deleteTrip() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - Top controls

    private var topControls: some View {
        HStack {
            CircleGlassButton(systemImage: "chevron.left", label: "戻る") { dismiss() }
            Spacer()
            CircleGlassMenu(systemImage: "ellipsis", label: "メニュー") {
                Button("編集", systemImage: "pencil") { showingEdit = true }
                Button("削除", systemImage: "trash", role: .destructive) { showingDeleteConfirm = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Hero

    private var hero: some View {
        heroBackground
            .frame(maxWidth: .infinity, minHeight: 330, maxHeight: 330)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.triporyNavy.opacity(0.35), Color.triporyNavy],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 130)
                    .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var heroBackground: some View {
        if let data = heroPhotoData, let uiImage = UIImage(data: data) {
            FilledPhoto(uiImage: uiImage)
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.triporySage.opacity(0.7), Color.triporyNavy],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: "airplane.departure")
                    .font(.system(size: 110))
                    .foregroundStyle(.white.opacity(0.14))
                    .rotationEffect(.degrees(-8))
            }
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                ForEach(trip.countries.prefix(6)) { country in
                    Text(country.flag).font(.title3)
                }
            }
            Text(trip.title.isEmpty ? String(localized: "旅行") : trip.title)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            if let start = trip.startDate {
                Text(dateRangeText(start: start, end: trip.endDate))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }
            HStack(spacing: 14) {
                Label(String(format: String(localized: "%lld日間"), trip.totalDays), systemImage: "clock")
                Label(String(format: String(localized: "%lldか国"), trip.countries.count), systemImage: "globe.asia.australia")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.top, -46) // ヒーロー下端のグラデーションに重ねる
        .accessibilityElement(children: .combine)
    }

    // MARK: - Collected countries (円形サムネイル)

    private var collectedCountries: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(trip.sortedStops) { stop in
                    if let country = stop.country {
                        NavigationLink(value: country) {
                            VStack(spacing: 8) {
                                ZStack {
                                    if let data = stop.photos.first, let image = UIImage(data: data) {
                                        FilledPhoto(uiImage: image)
                                    } else {
                                        LinearGradient(
                                            colors: [country.continent.tintColor, Color.triporyNavy],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        Text(country.flag).font(.title2)
                                    }
                                }
                                .frame(width: 68, height: 68)
                                .clipShape(Circle())
                                .contentShape(Circle())
                                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1.5))

                                Text(country.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(verbatim: isNew(stop) ? "NEW" : "REVISIT")
                                    .font(.caption2.weight(.black))
                                    .tracking(0.8)
                                    .foregroundStyle(isNew(stop) ? Color.triporyCoral : Color.triporyGold)
                            }
                            .frame(width: 84)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(country.name)、\(isNew(stop) ? String(localized: "初訪問") : String(localized: "再訪"))")
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        // VStack(alignment:.leading) の中で横スクロールが内容の理想幅まで
        // 広がらないよう、コンテナ幅に固定する。
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isNew(_ stop: TripStop) -> Bool {
        !allStops.contains {
            $0.persistentModelID != stop.persistentModelID
                && $0.countryCode == stop.countryCode
                && $0.startDate < stop.startDate
        }
    }

    // MARK: - Highlights

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("旅のハイライト")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                spacing: 8
            ) {
                ForEach(Array(highlightPhotos.prefix(8).enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        FilledPhoto(uiImage: image)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                            .accessibilityLabel("ハイライト写真 \(index + 1)")
                    }
                }
            }
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("旅のメモ")
            Text(trip.note)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Visit history

    private var visitHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("訪問の記録")
            VStack(spacing: 9) {
                ForEach(trip.sortedStops) { stop in
                    if let country = stop.country {
                        NavigationLink(value: country) {
                            HStack(spacing: 12) {
                                Text(country.flag).font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(country.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(stopDateText(stop))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                Spacer()
                                Text(verbatim: isNew(stop) ? "NEW" : "REVISIT")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(isNew(stop) ? Color.triporyCoral : Color.triporyGold)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            .padding(13)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.bold())
            .triporyTracking(1.2)
            .foregroundStyle(.white.opacity(0.55))
    }

    private func deleteTrip() {
        let codes = Set(trip.stops.map(\.countryCode))
        modelContext.delete(trip)
        modelContext.revertStatusIfOrphaned(codes: codes, homeCountryCode: homeCountryCode)
        dismiss()
    }

    private func dateRangeText(start: Date, end: Date?) -> String {
        let startText = start.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        guard let end, !Calendar.current.isDate(end, inSameDayAs: start) else { return startText }
        return "\(startText) - \(end.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))"
    }

    private func stopDateText(_ stop: TripStop) -> String {
        let start = stop.startDate.formatted(date: .abbreviated, time: .omitted)
        let base: String
        if let end = stop.endDate, !Calendar.current.isDate(end, inSameDayAs: stop.startDate) {
            base = "\(start) 〜 \(end.formatted(date: .abbreviated, time: .omitted))"
        } else {
            base = start
        }
        return "\(base) ・ \(stop.dayCount)\(String(localized: "日間"))"
    }
}

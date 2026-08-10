import SwiftUI
import SwiftData
import PhotosUI

/// 国の詳細 = ヒーロー写真に国名とメトリクスを重ね、
/// 「あなたの思い出」モザイクと「訪れた旅」リストを続ける構成。
struct CountryDetailView: View {
    let country: Country

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [CountryRecord]
    @Query(sort: \TripStop.startDate, order: .reverse) private var allStops: [TripStop]
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @State private var coverPhotoItem: PhotosPickerItem?
    @State private var isLoadingCover = false
    @State private var showingCoverPicker = false
    @Environment(TripFlowCoordinator.self) private var tripFlow

    private var record: CountryRecord? { records.first { $0.code == country.code } }
    private var status: CountryStatus { record?.status ?? .none }
    private var isHomeCountry: Bool { country.code == homeCountryCode }
    private var stops: [TripStop] { allStops.filter { $0.countryCode == country.code } }
    private var photos: [Data] { stops.flatMap(\.photos) }
    private var totalDays: Int { stops.reduce(0) { $0 + $1.dayCount } }
    private var firstVisitDate: Date? { stops.map(\.startDate).min() }
    private var latestVisitDate: Date? { stops.map(\.startDate).max() }
    /// ユーザーが選んだ表紙写真を最優先し、無ければ旅の写真から自動で選ぶ。
    private var heroPhotoData: Data? { record?.coverPhotoData ?? stops.flatMap(\.photos).first }
    private var hasCustomCover: Bool { record?.coverPhotoData != nil }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 28) {
                        if isHomeCountry { homeBadge }
                        if !stops.isEmpty { visitDateSummary }
                        if !isHomeCountry && stops.isEmpty { relationshipSection }
                        if status == .wantToGo { wantToGoNoteSection }
                        if !photos.isEmpty { memoryMosaic }
                        if !isHomeCountry { visitsSection }
                    }
                    .padding(20)
                    // 右下に浮かぶ追加ボタンの分、最後のリストが隠れないよう余白を確保する。
                    .padding(.bottom, 90)
                }
            }
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)

            topControls
        }
        .background(Color.triporyCanvas)
        .hidesNavigationBar()
        .swipeToGoBack()
        .navigationDestination(for: Trip.self) { TripDetailView(trip: $0) }
        // PhotosPicker は Menu の中に置くと開かないため、シート提示は独立させる。
        .photosPicker(isPresented: $showingCoverPicker, selection: $coverPhotoItem, matching: .images)
        .onChange(of: coverPhotoItem) { _, item in
            Task { await loadCover(item) }
        }
    }

    // MARK: - Top controls

    private var topControls: some View {
        HStack {
            CircleGlassButton(systemImage: "chevron.left", label: "戻る") { dismiss() }
            Spacer()
            coverPhotoMenu
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var coverPhotoMenu: some View {
        CircleGlassMenu(systemImage: isLoadingCover ? "progress.indicator" : "ellipsis", label: "表紙を編集") {
            Button(hasCustomCover ? "表紙の写真を変更" : "表紙の写真を選ぶ", systemImage: "photo") {
                showingCoverPicker = true
            }
            if hasCustomCover {
                Button("自動の写真に戻す", systemImage: "arrow.uturn.backward", role: .destructive) {
                    modelContext.record(for: country.code).coverPhotoData = nil
                    try? modelContext.save()
                }
            }
        }
        .disabled(isLoadingCover)
    }

    @MainActor
    private func loadCover(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingCover = true
        defer { isLoadingCover = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let compressed = ImageCompression.compress(data)
        else { return }
        modelContext.record(for: country.code).coverPhotoData = compressed
        try? modelContext.save()
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let heroPhotoData, let image = UIImage(data: heroPhotoData) {
                    FilledPhoto(uiImage: image)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [country.continent.tintColor.opacity(0.9), Color.triporyNavy],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: country.continent.symbolName)
                            .font(.system(size: 150, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.12))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 400, maxHeight: 400)
            .clipped()

            LinearGradient(
                colors: [.clear, Color.triporyPhotoOverlay.opacity(0.2), Color.triporyPhotoOverlay.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("\(country.name) \(country.flag)")
                    .font(.system(size: 42, weight: .semibold, design: .serif))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if !stops.isEmpty {
                    Text(String(
                        format: String(localized: "%1$lld回の訪問 ・ %2$lld日間"),
                        stops.count,
                        totalDays
                    ))
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.88)
                } else {
                    Text(status.displayName)
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.88)
                }
            }
            .foregroundStyle(.white)
            .padding(22)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(country.name)、訪問\(stops.count)回、合計\(totalDays)日")
    }

    // MARK: - Relationship

    private var visitDateSummary: some View {
        HStack(spacing: 10) {
            visitDateTile(title: "初回訪問", date: firstVisitDate, symbol: "flag.checkered")
            visitDateTile(title: "最終訪問", date: latestVisitDate, symbol: "clock.arrow.circlepath")
        }
    }

    private func visitDateTile(title: LocalizedStringKey, date: Date?, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(date?.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "不明"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.triporyInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private var homeBadge: some View {
        Label("今、住んでいる国", systemImage: "house.fill")
            .font(.headline)
            .foregroundStyle(Color.triporyInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.triporySage.opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
    }

    private var relationshipSection: some View {
        HStack(spacing: 12) {
            Label(status.displayName, systemImage: status.iconName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(status == .visited ? Color.triporyCoral : Color.triporyBlue)
            Spacer(minLength: 0)
            if status == .none {
                Button("行きたい国に追加", systemImage: "bookmark") { setStatus(.wantToGo) }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    .tint(Color.triporyBlue)
            } else if status == .wantToGo {
                Button("外す") { setStatus(.none) }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .tint(Color.triporyInk)
            }
        }
        .padding(16)
        .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Memory mosaic (大1枚+小2枚+「+N」)

    private var memoryMosaic: some View {
        VStack(alignment: .leading, spacing: 14) {
            TriporySectionHeader(title: "あなたの思い出")
            mosaicLayout
        }
    }

    @ViewBuilder
    private var mosaicLayout: some View {
        if photos.count == 1 {
            mosaicPhoto(photos[0], index: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 230)
        } else if photos.count == 2 {
            HStack(spacing: 8) {
                mosaicPhoto(photos[0], index: 0).frame(height: 165)
                mosaicPhoto(photos[1], index: 1).frame(height: 165)
            }
        } else {
            HStack(spacing: 8) {
                mosaicPhoto(photos[0], index: 0)
                    .frame(height: 226)

                VStack(spacing: 8) {
                    mosaicPhoto(photos[1], index: 1).frame(height: 109)
                    mosaicPhoto(photos[2], index: 2)
                        .frame(height: 109)
                        .overlay {
                            if photos.count > 3 {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15).fill(.black.opacity(0.55))
                                    Text(verbatim: "+\(photos.count - 3)")
                                        .font(.title3.weight(.bold).monospacedDigit())
                                        .foregroundStyle(.white)
                                }
                                .accessibilityLabel("ほかに\(photos.count - 3)枚の写真")
                            }
                        }
                }
                .frame(width: 118)
            }
        }
    }

    private func mosaicPhoto(_ data: Data, index: Int) -> some View {
        Group {
            if let image = UIImage(data: data) {
                FilledPhoto(uiImage: image)
            } else {
                Color.triporyCard
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .contentShape(RoundedRectangle(cornerRadius: 15))
        .accessibilityLabel("\(country.name)の思い出の写真 \(index + 1)")
    }

    // MARK: - Wishlist note

    private var wantToGoNoteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TriporySectionHeader(title: "なぜ行きたい？")
            TextEditor(text: noteBinding)
                .frame(minHeight: 96)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .topLeading) {
                    if noteBinding.wrappedValue.isEmpty {
                        Text("例：一度は見たいオーロラ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary.opacity(0.6))
                            .padding(18)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Visits

    private var visitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TriporySectionHeader(title: "訪れた旅", actionTitle: "追加", action: { tripFlow.presentNewTrip(presetCountryCode: country.code) })
            if stops.isEmpty {
                Text("まだ旅の記録がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 20))
            } else {
                VStack(spacing: 9) {
                    ForEach(stops) { stop in
                        if let trip = stop.trip {
                            visitRow(stop: stop, trip: trip)
                        }
                    }
                }
            }
        }
    }

    private func visitRow(stop: TripStop, trip: Trip) -> some View {
        NavigationLink(value: trip) {
            HStack(spacing: 14) {
                Text(String(Calendar.current.component(.year, from: stop.startDate)))
                    .font(.system(.subheadline, design: .serif, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.triporyCoral)
                    .frame(width: 46, alignment: .leading)

                Text(trip.title.isEmpty ? String(localized: "旅行") : trip.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.triporyInk)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(String(format: String(localized: "%lld日間"), stop.dayCount))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if let data = stop.photos.first, let image = UIImage(data: data) {
                    FilledPhoto(uiImage: image)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                } else {
                    Text(country.flag)
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .background(Color.triporyGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
                }
            }
            .padding(10)
            .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(trip.title)、\(stop.dayCount)日間")
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { record?.note ?? "" },
            set: { modelContext.record(for: country.code).note = $0 }
        )
    }

    private func setStatus(_ status: CountryStatus) {
        modelContext.record(for: country.code).status = status
    }
}

import SwiftUI
import SwiftData
import PhotosUI

/// 海外旅行を記録するシート。行き先を選ぶ時点で「行きたい国として登録」も選べるので、
/// ここから先は実際に訪れた場所の記録だけに絞っている。
struct TripFormView: View {
    var editingTrip: Trip?
    var presetCountryCode: String?
    var onSaved: (([NewCountryReveal], Int) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("homeCountryCode") private var homeCountryCode = ""

    @State private var stops: [StopDraft] = []
    @State private var title = ""
    @State private var note = ""
    @State private var heroPhotoData: Data?
    @State private var heroPhotoItem: PhotosPickerItem?
    @State private var showingCountryPicker = false
    @State private var didSetUp = false
    @State private var saveError: String?
    /// 一度でも「滞在期間を記録」がONにされたら、以降に追加する国はデフォルトでONにする
    @State private var recordDurationByDefault = false
    /// タイトル・メモ・表紙は任意項目なので、初期状態では畳んでおき、
    /// 「行き先と日程」だけで保存できる軽い入り口にする。既存の記録を編集する場合や、
    /// 既にどれかへ入力がある場合は開いた状態で始める。
    @State private var showingDetails = false

    struct StopDraft: Identifiable {
        let id = UUID()
        var countryCode: String
        var startDate = Date()
        var hasEndDate = false
        var endDate = Date()
        var photos: [Data] = []

        var country: Country? { CountryCatalog.byCode[countryCode] }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    EditorialTitle(text: editingTrip == nil ? "旅を記録する" : "旅を編集する")

                    if stops.isEmpty {
                        EmptyCollectionState(
                            title: "最初の国を選びましょう",
                            message: "訪れた国を追加すると、日付や写真を記録できます。",
                            actionTitle: "行き先を選ぶ",
                            action: { showingCountryPicker = true }
                        )
                        .padding(.top, 18)
                    } else {
                        // 「訪れた国」の一覧と「日付・写真」を別カードに分けていたのをやめ、
                        // 国ごとに1枚のカードへ統合する。1か国だけの旅では特に、
                        // 同じ国名を2度見せる冗長さがなくなる。
                        formStep(title: "行き先と日程") {
                            VStack(spacing: 14) {
                                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stopValue in
                                    StopEditorRow(
                                        stop: $stops[index],
                                        recordDurationByDefault: $recordDurationByDefault,
                                        canMoveUp: index > 0,
                                        canMoveDown: index < stops.count - 1,
                                        onMoveUp: { moveStop(id: stopValue.id, offset: -1) },
                                        onMoveDown: { moveStop(id: stopValue.id, offset: 1) },
                                        onDelete: { withAnimation { stops.removeAll { $0.id == stopValue.id } } }
                                    )
                                }
                                addCountryButton
                            }
                        }

                        // タイトル・メモ・表紙は保存に必須ではない任意項目。常に開いていると
                        // 「行き先と日程を記録するだけ」の軽い操作にも毎回目を通す負担が乗るため、
                        // 初期状態は畳んでおき、必要な人だけ開いて使う。
                        detailsDisclosure

                        PrimaryCapsuleButton(title: "この旅を保存する") {
                            save()
                        }
                        .accessibilityHint("旅の記録を保存します")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .background(Color.triporyCanvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCountryPicker) {
                CountryPickerView(
                    onSelect: { country in appendStop(code: country.code) },
                    onMarkWantToGo: { country in markWantToGo(country) },
                    excludingCode: homeCountryCode
                )
            }
            .onAppear(perform: setUp)
            .alert("保存できませんでした", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("閉じる", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "もう一度お試しください。")
            }
        }
    }

    private func formStep<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .serif, weight: .semibold))
            content()
        }
    }

    /// タイトル・メモ・表紙が同じ見た目の灰色ボックスで並ぶと見分けにくいため、
    /// 小さなラベルを添えて何の入力欄かひと目でわかるようにする。
    private func labeledField<Content: View>(
        _ label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var addCountryButton: some View {
        Button {
            showingCountryPicker = true
        } label: {
            Label("次の国を追加", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    /// タイトル・メモ・表紙をまとめた任意項目。折りたたみ式にして、
    /// 「行き先と日程」だけでも保存できることを視覚的にも伝える。
    private var detailsDisclosure: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.snappy(duration: 0.22)) { showingDetails.toggle() }
            } label: {
                HStack {
                    Label("タイトル・メモ・表紙", systemImage: "text.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.triporyInk)
                    Text("(任意)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showingDetails ? 180 : 0))
                }
                .padding(15)
                .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)

            if showingDetails {
                memoryCard
            }
        }
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            labeledField("タイトル") {
                TextField(suggestedTitle, text: $title)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color.triporyNavy.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            }
            labeledField("メモ") {
                TextField("この旅で覚えておきたいこと", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color.triporyNavy.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            }
            labeledField("表紙") {
                heroPhotoPicker
            }
        }
        .padding(15)
        .background(Color.triporyCard, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var heroPhotoPicker: some View {
        PhotosPicker(selection: $heroPhotoItem, matching: .images) {
            if let data = heroPhotoData, let uiImage = UIImage(data: data) {
                FilledPhoto(uiImage: uiImage)
                    .frame(maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .black.opacity(0.4))
                            .padding(8)
                    }
            } else {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("表紙の写真を選ぶ(任意)")
                    Spacer()
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.triporyGold)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(Color.triporyGold.opacity(0.4))
                )
            }
        }
        .buttonStyle(.plain)
        .onChange(of: heroPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    let compressed = ImageCompression.compress(data) ?? data
                    await MainActor.run { heroPhotoData = compressed }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if heroPhotoData != nil {
                Button("表紙を解除", systemImage: "xmark.circle.fill", role: .destructive) {
                    heroPhotoData = nil
                    heroPhotoItem = nil
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .font(.caption.bold())
                .padding(8)
            }
        }
    }

    private var suggestedTitle: String {
        let names = stops.compactMap { $0.country?.name }
        guard !names.isEmpty else { return String(localized: "タイトル(任意)") }
        return String(format: String(localized: "%@の記録"), names.joined(separator: "・"))
    }

    // MARK: - Logic

    private func setUp() {
        guard !didSetUp else { return }
        didSetUp = true

        if let trip = editingTrip {
            title = trip.title
            note = trip.note
            heroPhotoData = trip.heroPhotoData
            stops = trip.sortedStops.map {
                StopDraft(
                    countryCode: $0.countryCode,
                    startDate: $0.startDate,
                    hasEndDate: $0.endDate != nil,
                    endDate: $0.endDate ?? $0.startDate,
                    photos: $0.photos
                )
            }
            recordDurationByDefault = stops.contains { $0.hasEndDate }
            // 編集時は既にタイトル・メモ・表紙が入っている可能性が高いので、
            // 畳んだままにせず開いた状態で見せる。
            showingDetails = true
        } else if let code = presetCountryCode {
            appendStop(code: code)
        } else {
            showingCountryPicker = true
        }
    }

    /// 新しい訪問先を追加する。前の訪問先と同じ日付をデフォルトにする(同日に複数国訪れるケースもあるため)。
    private func appendStop(code: String) {
        var draft = StopDraft(countryCode: code)
        if let last = stops.last {
            draft.hasEndDate = recordDurationByDefault
            let base = last.hasEndDate ? last.endDate : last.startDate
            draft.startDate = base
            draft.endDate = base
        }
        stops.append(draft)
    }

    private func moveStop(id: StopDraft.ID, offset: Int) {
        guard let index = stops.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard stops.indices.contains(target) else { return }
        withAnimation {
            stops.swapAt(index, target)
        }
    }

    private func markWantToGo(_ country: Country) {
        let record = modelContext.record(for: country.code)
        if record.status == .none { record.status = .wantToGo }
        // 行き先を1つも選んでいない状態で「行きたい」だけ登録した場合は、それで完了とする
        if stops.isEmpty { dismiss() }
    }

    private func save() {
        guard !stops.isEmpty else { return }

        let existingStops = (try? modelContext.fetch(FetchDescriptor<TripStop>())) ?? []
        let editingTripID = editingTrip?.persistentModelID
        let newCountries = Dictionary(grouping: stops, by: \.countryCode)
            .compactMap { code, drafts -> (Country, Date, Data?)? in
                guard let country = CountryCatalog.byCode[code],
                      let firstDraftDate = drafts.map(\.startDate).min()
                else { return nil }
                let hadEarlierVisit = existingStops.contains { existing in
                    guard existing.countryCode == code,
                          existing.trip?.persistentModelID != editingTripID
                    else { return false }
                    return existing.startDate < firstDraftDate
                }
                guard !hadEarlierVisit else { return nil }
                let photo = drafts.compactMap(\.photos.first).first ?? heroPhotoData
                return (country, firstDraftDate, photo)
            }
            .sorted { $0.1 < $1.1 }
            .map { NewCountryReveal(country: $0.0, coverPhotoData: $0.2) }

        let trip = editingTrip ?? Trip()
        if editingTrip == nil { modelContext.insert(trip) }
        let previousCodes = Set(trip.stops.map(\.countryCode))
        for existingStop in trip.stops { modelContext.delete(existingStop) }

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        trip.title = trimmedTitle.isEmpty ? suggestedTitle : trimmedTitle
        trip.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.heroPhotoData = heroPhotoData

        for (index, draft) in stops.enumerated() {
            let stop = TripStop(
                order: index,
                countryCode: draft.countryCode,
                startDate: draft.startDate,
                endDate: draft.hasEndDate ? draft.endDate : nil,
                photos: draft.photos
            )
            stop.trip = trip
            modelContext.insert(stop)

            // 行きたい国だった場合も、実際に訪れたので訪問済みに切り替える
            modelContext.record(for: draft.countryCode).status = .visited
        }

        // 編集で訪問先から外された国は、他に参照がなければ訪問済みを取り消す
        let removedCodes = previousCodes.subtracting(stops.map(\.countryCode))
        modelContext.revertStatusIfOrphaned(codes: removedCodes, homeCountryCode: homeCountryCode)

        do {
            try modelContext.save()
            let recordCount = (try? modelContext.fetch(FetchDescriptor<CountryRecord>()))?
                .filter { $0.status.countsAsVisited && $0.code != homeCountryCode }
                .count ?? 0
            dismiss()
            if !newCountries.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onSaved?(newCountries, recordCount)
                }
            } else {
                onSaved?(newCountries, recordCount)
            }
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}

/// 1つの訪問先を編集する行(常に「訪問した場所」として扱う)。
private struct StopEditorRow: View {
    @Binding var stop: TripFormView.StopDraft
    @Binding var recordDurationByDefault: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            photoPicker
            DatePicker("訪れた日", selection: $stop.startDate, displayedComponents: .date)
                .font(.subheadline)
            Toggle("滞在期間を記録", isOn: $stop.hasEndDate.animation())
                .font(.subheadline)
                .onChange(of: stop.hasEndDate) { _, newValue in
                    if newValue {
                        recordDurationByDefault = true
                        stop.endDate = stop.startDate
                    }
                }
            if stop.hasEndDate {
                DatePicker("終了日", selection: $stop.endDate, in: stop.startDate..., displayedComponents: .date)
                    .font(.subheadline)
            }
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
        // PhotosPickerのselectionは「今開いたときに選んだ内容」を表すだけなので、
        // 読み込み次第これまでの写真に追加して、選択はいったん空に戻す
        // (次に開いたときにまた新規で選べるようにする=積み増し方式)。
        .onChange(of: photoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var loaded: [Data] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(ImageCompression.compress(data) ?? data)
                    }
                }
                await MainActor.run {
                    stop.photos.append(contentsOf: loaded)
                    photoItems = []
                }
            }
        }
    }

    // 上へ・下へ・削除の3つのアイコンが並ぶと目移りしやすいため、1つの「⋯」メニューに
    // まとめる。並び替え自体は上の「訪れた国」リストの並び順と連動しているので、
    // ここでは「編集中の国を動かす/消す」操作だとわかればよい。
    private var headerRow: some View {
        HStack {
            if let country = stop.country {
                Text(country.flag).font(.title2)
                Text(country.name)
                    .font(.system(size: 17, weight: .bold, design: .serif))
            }
            Spacer()
            Menu {
                Button("上に移動", systemImage: "chevron.up", action: onMoveUp)
                    .disabled(!canMoveUp)
                Button("下に移動", systemImage: "chevron.down", action: onMoveDown)
                    .disabled(!canMoveDown)
                Button("この国を削除", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var photoPicker: some View {
        if stop.photos.isEmpty {
            PhotosPicker(selection: $photoItems, matching: .images) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text("写真を追加")
                    Spacer()
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.triporyBlue)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(Color.triporyBlue.opacity(0.4))
                )
            }
            .buttonStyle(.plain)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(stop.photos.enumerated()), id: \.offset) { index, data in
                        if let uiImage = UIImage(data: data) {
                            FilledPhoto(uiImage: uiImage)
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        stop.photos.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.footnote)
                                            .foregroundStyle(.white, .black.opacity(0.5))
                                    }
                                    .padding(5)
                                }
                                .accessibilityLabel("写真 \(index + 1)")
                                .accessibilityAction(named: "削除") { stop.photos.remove(at: index) }
                        }
                    }

                    PhotosPicker(selection: $photoItems, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("追加")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(Color.triporyBlue)
                        .frame(width: 96, height: 96)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                                .foregroundStyle(Color.triporyBlue.opacity(0.4))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("写真を追加")
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
    }
}

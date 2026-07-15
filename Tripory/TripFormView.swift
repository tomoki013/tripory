import SwiftUI
import SwiftData
import PhotosUI

/// 海外旅行を記録するシート。行き先を選ぶ時点で「行きたい国として登録」も選べるので、
/// ここから先は実際に訪れた場所の記録だけに絞っている。
struct TripFormView: View {
    var editingTrip: Trip?
    var presetCountryCode: String?

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
    /// 一度でも「滞在期間を記録」がONにされたら、以降に追加する国はデフォルトでONにする
    @State private var recordDurationByDefault = false

    struct StopDraft: Identifiable {
        let id = UUID()
        var countryCode: String
        var startDate = Date()
        var hasEndDate = false
        var endDate = Date()
        var photoData: Data?

        var country: Country? { CountryCatalog.byCode[countryCode] }
    }

    var body: some View {
        NavigationStack {
            Form {
                placesSection
                if !stops.isEmpty {
                    memorySection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(editingTrip == nil ? "新しい記録" : "記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.bold)
                        .disabled(stops.isEmpty)
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
        }
    }

    // MARK: - 訪れた場所

    private var placesSection: some View {
        Section {
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
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
            .onMove { stops.move(fromOffsets: $0, toOffset: $1) }

            Button {
                showingCountryPicker = true
            } label: {
                Label(stops.isEmpty ? "行き先を選ぶ" : "次の行き先を追加", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
            }
        } header: {
            Text("訪れた場所")
        } footer: {
            if stops.count > 1 {
                Text("長押しして動かすと順番を入れ替えられます")
            }
        }
    }

    // MARK: - 思い出

    private var memorySection: some View {
        Section {
            TextField(suggestedTitle, text: $title)
            TextField("メモ(任意)", text: $note, axis: .vertical)
                .lineLimit(3...6)
            heroPhotoPicker
        } header: {
            Text("思い出")
        } footer: {
            Text("表紙の写真を選ばない場合は、最初の訪問先の写真が自動で使われます")
        }
    }

    @ViewBuilder
    private var heroPhotoPicker: some View {
        PhotosPicker(selection: $heroPhotoItem, matching: .images) {
            if let data = heroPhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                    .clipped()
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
                .foregroundStyle(.orange)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(.orange.opacity(0.4))
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
                Button(role: .destructive) {
                    heroPhotoData = nil
                    heroPhotoItem = nil
                } label: {
                    Label("表紙を解除", systemImage: "xmark.circle.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())
                        .foregroundStyle(.white)
                }
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
                    photoData: $0.photoData
                )
            }
            recordDurationByDefault = stops.contains { $0.hasEndDate }
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
                photoData: draft.photoData
            )
            stop.trip = trip
            modelContext.insert(stop)

            // 行きたい国だった場合も、実際に訪れたので訪問済みに切り替える
            modelContext.record(for: draft.countryCode).status = .visited
        }

        // 編集で訪問先から外された国は、他に参照がなければ訪問済みを取り消す
        let removedCodes = previousCodes.subtracting(stops.map(\.countryCode))
        modelContext.revertStatusIfOrphaned(codes: removedCodes, homeCountryCode: homeCountryCode)

        dismiss()
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

    @State private var photoItem: PhotosPickerItem?

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
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    let compressed = ImageCompression.compress(data) ?? data
                    await MainActor.run { stop.photoData = compressed }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            if let country = stop.country {
                Text(country.flag).font(.title2)
                Text(country.name)
                    .font(.system(size: 17, weight: .bold, design: .serif))
            }
            Spacer()
            HStack(spacing: 14) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveDown)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            if let data = stop.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .black.opacity(0.4))
                            .padding(8)
                    }
            } else {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text("写真を追加")
                    Spacer()
                }
                .font(.subheadline.bold())
                .foregroundStyle(.teal)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(.teal.opacity(0.4))
                )
            }
        }
        .buttonStyle(.plain)
    }
}

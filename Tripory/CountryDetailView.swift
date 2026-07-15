import SwiftUI
import SwiftData

struct CountryDetailView: View {
    let country: Country

    @Environment(\.modelContext) private var modelContext
    @Query private var records: [CountryRecord]
    @Query(sort: \TripStop.startDate, order: .reverse) private var allStops: [TripStop]
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @State private var showingAddTrip = false

    private var record: CountryRecord? {
        records.first { $0.code == country.code }
    }

    private var status: CountryStatus { record?.status ?? .none }

    private var isHomeCountry: Bool { country.code == homeCountryCode }

    private var stops: [TripStop] {
        allStops.filter { $0.countryCode == country.code }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                statusSection
                if status == .wantToGo {
                    wantToGoNoteSection
                }
                if !isHomeCountry {
                    historySection
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground)
        .navigationTitle(country.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddTrip) {
            TripFormView(presetCountryCode: country.code)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(country.flag)
                    .font(.system(size: 42))
                VStack(alignment: .leading, spacing: 3) {
                    Text(country.continent.displayName.uppercased())
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundStyle(.teal)
                    Text(country.name)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                }
                Spacer()
            }
            Rectangle()
                .fill(LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .opacity(0.5)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if isHomeCountry {
            HStack(spacing: 10) {
                Image(systemName: "house.fill")
                    .foregroundStyle(.indigo)
                Text("住んでいる国です")
                    .font(.subheadline.bold())
                Spacer()
            }
            .padding(14)
            .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        } else {
            HStack(spacing: 10) {
                statusBadge
                Spacer()
                if status == .none {
                    Button("行きたい国に追加") { record(.wantToGo) }
                        .font(.subheadline.bold())
                } else if status == .wantToGo {
                    Button("行きたい国から外す") { record(.none) }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if status == .visited && stops.isEmpty {
                    // 旅の記録に紐づかない訪問済み(住んでいる国の設定ミスなど)は、ここから直接取り消せるようにする
                    Button("訪問済みから外す") { record(.none) }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var wantToGoNoteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("なぜ行きたい?")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1)
            ZStack(alignment: .topLeading) {
                TextEditor(text: noteBinding)
                    .font(.subheadline)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)

                if noteBinding.wrappedValue.isEmpty {
                    Text("例: 一度は見たいオーロラ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(10)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { record?.note ?? "" },
            set: { modelContext.record(for: country.code).note = $0 }
        )
    }

    private var statusBadge: some View {
        Label(status.displayName, systemImage: status.iconName)
            .font(.subheadline.bold())
            .foregroundStyle(status.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.12), in: Capsule())
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("旅の記録")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                Button {
                    showingAddTrip = true
                } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                }
            }
            .padding(.bottom, 10)

            if stops.isEmpty {
                Text("まだ旅の記録がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 8) {
                    ForEach(stops) { stop in
                        StopHistoryRow(stop: stop)
                    }
                }
            }
        }
    }

    private func record(_ newStatus: CountryStatus) {
        modelContext.record(for: country.code).status = newStatus
    }
}

private struct StopHistoryRow: View {
    let stop: TripStop

    var body: some View {
        NavigationLink(value: stop.trip) {
            HStack(alignment: .center, spacing: 12) {
                if let data = stop.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                        .frame(width: 26)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.trip?.title.isEmpty == false ? stop.trip!.title : String(localized: "旅行"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(dateRangeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var dateRangeText: String {
        let start = stop.startDate.formatted(date: .abbreviated, time: .omitted)
        if let end = stop.endDate {
            return "\(start) 〜 \(end.formatted(date: .abbreviated, time: .omitted))"
        }
        return start
    }
}

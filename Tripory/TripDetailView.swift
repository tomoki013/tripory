import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("homeCountryCode") private var homeCountryCode = ""
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    private var heroPhotoData: Data? {
        trip.heroPhotoData ?? trip.sortedStops.compactMap(\.photoData).first
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 26) {
                        statsStrip
                        itinerary
                        if !trip.note.isEmpty { noteCard }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)

            topControls
        }
        .background(Color.appBackground)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEdit) {
            TripFormView(editingTrip: trip)
        }
        .alert("この旅を削除しますか?", isPresented: $showingDeleteConfirm) {
            Button("削除する", role: .destructive) { deleteTrip() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - Top controls (custom back + menu overlaid on the hero)

    private var topControls: some View {
        HStack {
            circleButton(system: "chevron.left") { dismiss() }
            Spacer()
            Menu {
                Button("編集", systemImage: "pencil") { showingEdit = true }
                Button("削除", systemImage: "trash", role: .destructive) { showingDeleteConfirm = true }
            } label: {
                circleIcon(system: "ellipsis")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func circleButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { circleIcon(system: system) }
    }

    private func circleIcon(system: String) -> some View {
        Image(systemName: system)
            .font(.body.bold())
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(.black.opacity(0.35), in: Circle())
    }

    // MARK: - Hero

    private var hero: some View {
        heroBackground
            .frame(maxWidth: .infinity, minHeight: 320, maxHeight: 320)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.15), .black.opacity(0.78)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 130)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(trip.countries) { country in
                            Text(country.flag).font(.title2)
                        }
                    }
                    Text(trip.title.isEmpty ? String(localized: "旅行") : trip.title)
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    if let start = trip.startDate {
                        Label(dateRangeText(start: start, end: trip.endDate), systemImage: "calendar")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
    }

    @ViewBuilder
    private var heroBackground: some View {
        if let data = heroPhotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [.teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "airplane.departure")
                    .font(.system(size: 130))
                    .foregroundStyle(.white.opacity(0.18))
                    .rotationEffect(.degrees(-8))
            }
        }
    }

    // MARK: - Stats

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statItem(value: "\(trip.countries.count)", unit: "ヶ国", icon: "globe.asia.australia.fill", color: .teal)
            statDivider
            statItem(value: "\(trip.totalDays)", unit: "日間", icon: "moon.stars.fill", color: .indigo)
            if trip.sortedStops.count >= 2 {
                statDivider
                statItem(value: "\(trip.sortedStops.count)", unit: "訪問", icon: "mappin.and.ellipse", color: .orange)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private func statItem(value: String, unit: LocalizedStringKey, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 34)
    }

    // MARK: - Itinerary (timeline)

    private var itinerary: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("旅のルート")

            VStack(spacing: 0) {
                let stops = trip.sortedStops
                ForEach(Array(stops.enumerated()), id: \.element.persistentModelID) { index, stop in
                    timelineRow(index: index, stop: stop, isLast: index == stops.count - 1)
                }
            }
        }
    }

    private func timelineRow(index: Int, stop: TripStop, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("\(index + 1)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)

                if !isLast {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.teal.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 30)

            VStack(spacing: 0) {
                if let country = stop.country {
                    stopCard(country: country, stop: stop)
                }
                if !isLast {
                    Color.clear.frame(height: 18)
                }
            }
        }
    }

    private func stopCard(country: Country, stop: TripStop) -> some View {
        NavigationLink(value: country) {
            VStack(alignment: .leading, spacing: 0) {
                if let data = stop.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                        .clipped()
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
                }
                HStack(spacing: 10) {
                    Text(country.flag).font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(country.name)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                        Text(stopDateText(stop))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("メモ")
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [.teal, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3)
                Text(trip.note)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.bold())
            .tracking(1.5)
            .foregroundStyle(.secondary)
            .padding(.bottom, 14)
    }

    private func deleteTrip() {
        let codes = Set(trip.stops.map(\.countryCode))
        modelContext.delete(trip)
        modelContext.revertStatusIfOrphaned(codes: codes, homeCountryCode: homeCountryCode)
        dismiss()
    }

    private func dateRangeText(start: Date, end: Date?) -> String {
        let startText = start.formatted(date: .abbreviated, time: .omitted)
        guard let end, !Calendar.current.isDate(end, inSameDayAs: start) else { return startText }
        return "\(startText) 〜 \(end.formatted(date: .abbreviated, time: .omitted))"
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

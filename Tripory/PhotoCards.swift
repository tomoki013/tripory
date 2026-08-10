import SwiftUI

/// scaledToFillで拡大した写真は .clipped() しても「描画」だけが切り取られ、
/// タップ判定は枠の外まで残る。カード内の写真は必ずこれで表示し、
/// 枠外のタップ横取り(別のボタンが反応しない/隣のカードが開く)を防ぐ。
struct FilledPhoto: View {
    let uiImage: UIImage

    var body: some View {
        Color.clear
            .overlay(
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            )
            .clipped()
            .contentShape(Rectangle())
    }
}

/// 旅の記録(タイムライン)用の写真カード。タイトルと小さなメタチップを写真に重ねる。
struct TripCoverCard: View {
    let trip: Trip

    private var photoData: Data? {
        trip.heroPhotoData ?? trip.sortedStops.flatMap(\.photos).first
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let photoData, let image = UIImage(data: photoData) {
                    FilledPhoto(uiImage: image)
                } else {
                    tripPlaceholder
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)

            LinearGradient(colors: [.clear, Color.triporyPhotoOverlay.opacity(0.8)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Text(trip.title.isEmpty ? trip.routeDescription : trip.title)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    metaChip {
                        Text(trip.countries.prefix(4).map(\.flag).joined(separator: " "))
                    }
                    metaChip {
                        Text(String(format: String(localized: "%lld日間"), trip.totalDays))
                    }
                    metaChip {
                        Text(String(format: String(localized: "%lldか国"), trip.countries.count))
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(trip.title)、\(trip.totalDays)日間、\(trip.countries.count)か国")
    }

    private func metaChip(@ViewBuilder content: () -> some View) -> some View {
        content()
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .triporyGlass(in: Capsule(), tint: .black.opacity(0.38))
    }

    private var tripPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.triporyNavy, Color.triporySage.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.triporyGold.opacity(0.94))
                .frame(width: 84, height: 84)
                .triporyDecorativeOffset(x: 92, y: -46)
            Image(systemName: "airplane")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.white)
        }
    }
}

/// 国コレクション用の全幅フォトカード。NEWバッジ・国名+国旗・訪問メトリクスを重ねる。
struct CountryCoverCard: View {
    let summary: CountryMemorySummary
    var showsNewBadge = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = summary.coverPhotoData, let image = UIImage(data: data) {
                    FilledPhoto(uiImage: image)
                } else {
                    designedPlaceholder
                }
            }
            .frame(maxWidth: .infinity, minHeight: 172, maxHeight: 172)

            LinearGradient(colors: [.clear, Color.triporyPhotoOverlay.opacity(0.8)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(summary.country.name) \(summary.country.flag)")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .lineLimit(1)
                if summary.visitCount > 0 {
                    Text(String(
                        format: String(localized: "%1$lld回の訪問 ・ %2$lld日間"),
                        summary.visitCount,
                        summary.totalDays
                    ))
                    .font(.caption.weight(.semibold))
                    .opacity(0.86)
                } else {
                    Text(summary.status.displayName)
                        .font(.caption.weight(.semibold))
                        .opacity(0.86)
                }
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 172, maxHeight: 172)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .overlay(alignment: .topLeading) {
            if showsNewBadge {
                Text("新規")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .triporyGlass(in: Capsule(), tint: Color.triporyCoral)
                    .padding(11)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.country.name)、\(summary.visitCount)回訪問、合計\(summary.totalDays)日")
    }

    private var designedPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [summary.country.continent.tintColor.opacity(0.82), Color.triporyNavy],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: summary.country.continent.symbolName)
                .font(.system(size: 84, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.17))
                .triporyDecorativeOffset(x: 52, y: -26)
            Text(summary.country.code)
                .font(.system(size: 58, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.12))
                .triporyDecorativeOffset(x: -56, y: 22)
        }
    }
}

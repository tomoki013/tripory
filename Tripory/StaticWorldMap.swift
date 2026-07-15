import SwiftUI
import MapKit
import UIKit

/// 訪問国を国境ポリゴンで塗りつぶす世界地図。
/// MapKitは最小ズームがクランプされ1枚で全世界(経度360°)を表示できないため、
/// 経度帯ごとのパネルに分割し、呼び出し側で貼り合わせて縮小表示する。
struct StaticWorldMap: UIViewRepresentable {
    let records: [CountryRecord]
    let minLon: Double
    let maxLon: Double
    var displayMode: MapDisplayMode = .color
    var visitedOnly = false
    var isDarkMode = false

    static let latTop: Double = 78
    static let latBottom: Double = -58

    /// 全世界(横360°・緯度78N〜58S)の高さ/幅 比
    static var worldAspectRatio: CGFloat {
        let yTop = MKMapPoint(CLLocationCoordinate2D(latitude: latTop, longitude: 0)).y
        let yBottom = MKMapPoint(CLLocationCoordinate2D(latitude: latBottom, longitude: 0)).y
        return (yBottom - yTop) / MKMapSize.world.width
    }

    /// bounds確定後・変更後に必ず指定rectへフィットし直すMKMapView
    final class FittingMapView: MKMapView {
        var fitRect = MKMapRect.world
        private var lastFitSize: CGSize = .zero

        override func layoutSubviews() {
            super.layoutSubviews()
            if bounds.size != lastFitSize, bounds.size != .zero {
                lastFitSize = bounds.size
                setVisibleMapRect(fitRect, animated: false)
            }
        }
    }

    private var panelRect: MKMapRect {
        let world = MKMapSize.world.width
        let x = world * (minLon + 180) / 360
        let width = world * (maxLon - minLon) / 360
        let yTop = MKMapPoint(CLLocationCoordinate2D(latitude: Self.latTop, longitude: 0)).y
        let yBottom = MKMapPoint(CLLocationCoordinate2D(latitude: Self.latBottom, longitude: 0)).y
        return MKMapRect(x: x, y: yTop, width: width, height: yBottom - yTop)
    }

    func makeUIView(context: Context) -> FittingMapView {
        let mapView = FittingMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isUserInteractionEnabled = false
        mapView.fitRect = panelRect
        return mapView
    }

    func updateUIView(_ mapView: FittingMapView, context: Context) {
        mapView.fitRect = panelRect
        mapView.removeOverlays(mapView.overlays)
        context.coordinator.displayMode = displayMode
        context.coordinator.isDarkMode = isDarkMode

        let recordedCodes = Set(records.compactMap { $0.status != .none ? $0.country?.code : nil })

        if displayMode == .monochrome {
            for wash in MapColoringMode.washPolygons(minLon: minLon, maxLon: maxLon) {
                wash.title = "wash"
                mapView.addOverlay(wash)
            }

            // 塗り絵帳のように、記録のない国も含めてすべての国境線を黒で表示する
            for (code, polygons) in CountryBorders.polygonsByCode where !recordedCodes.contains(code) {
                for polygon in polygons {
                    polygon.title = "border"
                    mapView.addOverlay(polygon)
                }
            }
        }

        for record in records {
            guard record.status != .none, let country = record.country else { continue }
            // 「訪問済みのみ」表示では、行きたい国は一切表示しない
            if visitedOnly && !record.status.countsAsVisited { continue }
            for polygon in CountryBorders.polygonsByCode[country.code] ?? [] {
                polygon.title = record.status.countsAsVisited ? "visited" : "want"
                mapView.addOverlay(polygon)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var displayMode: MapDisplayMode = .color
        var isDarkMode = false

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolygonRenderer(polygon: polygon)
            let mono = displayMode == .monochrome
            let monoStroke: UIColor = isDarkMode ? .white : .black
            switch polygon.title {
            case "wash":
                MapColoringMode.style(renderer, isDarkMode: isDarkMode)
            case "border":
                MapColoringMode.borderStyle(renderer, lineWidth: 0.5, isDarkMode: isDarkMode)
            case "visited":
                renderer.fillColor = UIColor.systemTeal.withAlphaComponent(0.75)
                renderer.strokeColor = mono ? monoStroke : UIColor.systemTeal
                renderer.lineWidth = mono ? 0.5 : 0.75
            default:
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.55)
                renderer.strokeColor = mono ? monoStroke : UIColor.systemOrange
                renderer.lineWidth = mono ? 0.5 : 0.75
            }
            return renderer
        }
    }
}

/// 3枚のパネルを貼り合わせた全世界マップ(継ぎ目は大西洋・太平洋上)
struct WorldMapCard: View {
    let records: [CountryRecord]
    var displayMode: MapDisplayMode = .color
    var visitedOnly = false

    @Environment(\.colorScheme) private var colorScheme

    // 継ぎ目の経度: 国のポリゴンに重ならない海上を選ぶ
    private static let seams: [Double] = [-180, -28.5, 156, 180]
    private static let totalWidth: CGFloat = 1800

    var body: some View {
        GeometryReader { geo in
            let unit = Self.totalWidth / 360
            let height = Self.totalWidth * StaticWorldMap.worldAspectRatio
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    StaticWorldMap(
                        records: records,
                        minLon: Self.seams[index],
                        maxLon: Self.seams[index + 1],
                        displayMode: displayMode,
                        visitedOnly: visitedOnly,
                        isDarkMode: colorScheme == .dark
                    )
                    .frame(
                        width: (Self.seams[index + 1] - Self.seams[index]) * unit,
                        height: height
                    )
                }
            }
            .scaleEffect(geo.size.width / Self.totalWidth, anchor: .topLeading)
        }
        .aspectRatio(1 / StaticWorldMap.worldAspectRatio, contentMode: .fit)
    }
}

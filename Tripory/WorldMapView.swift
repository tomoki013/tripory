import SwiftUI
import MapKit
import SwiftData

/// 自由に拡大縮小・パンできる全画面マップ。国のポリゴンをタップすると詳細へ遷移する。
struct InteractiveWorldMap: UIViewRepresentable {
    let records: [CountryRecord]
    var displayMode: MapDisplayMode = .color
    var visitedOnly = false
    var isDarkMode = false
    let onSelectCode: (String) -> Void

    private static let worldCamera = MKMapCamera(
        lookingAtCenter: CLLocationCoordinate2D(latitude: 20, longitude: 20),
        fromDistance: 2.2e7,
        pitch: 0,
        heading: 0
    )

    /// bounds確定前にcameraを設定すると、MapKit内部のMetalレイヤーが0x0サイズで
    /// 描画しようとして警告が出るため、実サイズが決まった最初のレイアウトで一度だけ設定する。
    final class InitialCameraMapView: MKMapView {
        var initialCamera: MKMapCamera?
        private var didSetInitialCamera = false

        override func layoutSubviews() {
            super.layoutSubviews()
            guard !didSetInitialCamera, bounds.size != .zero, let initialCamera else { return }
            didSetInitialCamera = true
            camera = initialCamera
        }
    }

    func makeUIView(context: Context) -> InitialCameraMapView {
        let mapView = InitialCameraMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.initialCamera = Self.worldCamera

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)
        context.coordinator.mapView = mapView
        context.coordinator.onSelectCode = onSelectCode
        return mapView
    }

    func updateUIView(_ mapView: InitialCameraMapView, context: Context) {
        context.coordinator.onSelectCode = onSelectCode
        context.coordinator.displayMode = displayMode
        context.coordinator.isDarkMode = isDarkMode
        mapView.removeOverlays(mapView.overlays)
        context.coordinator.codeByPolygon.removeAll()

        let recordedCodes = Set(records.compactMap { $0.status != .none ? $0.country?.code : nil })

        if displayMode == .monochrome {
            for wash in MapColoringMode.washPolygons(minLon: -180, maxLon: 180) {
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
                context.coordinator.codeByPolygon[ObjectIdentifier(polygon)] = country.code
                mapView.addOverlay(polygon)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        weak var mapView: MKMapView?
        var onSelectCode: ((String) -> Void)?
        var codeByPolygon: [ObjectIdentifier: String] = [:]
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
                renderer.lineWidth = mono ? 0.5 : 1
            default:
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.55)
                renderer.strokeColor = mono ? monoStroke : UIColor.systemOrange
                renderer.lineWidth = mono ? 0.5 : 1
            }
            return renderer
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView, gesture.state == .ended else { return }
            let point = gesture.location(in: mapView)
            let tapCoordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let tapMapPoint = MKMapPoint(tapCoordinate)

            // 小さい国(飛び地)を優先してヒットテストする
            let candidates = mapView.overlays
                .compactMap { $0 as? MKPolygon }
                .sorted { $0.boundingMapRect.size.width * $0.boundingMapRect.size.height
                        < $1.boundingMapRect.size.width * $1.boundingMapRect.size.height }

            for polygon in candidates {
                guard polygon.boundingMapRect.contains(tapMapPoint),
                      let renderer = mapView.renderer(for: polygon) as? MKPolygonRenderer,
                      let path = renderer.path
                else { continue }
                let rendererPoint = renderer.point(for: tapMapPoint)
                if path.contains(rendererPoint), let code = codeByPolygon[ObjectIdentifier(polygon)] {
                    onSelectCode?(code)
                    return
                }
            }
        }
    }
}

struct FullMapView: View {
    @Query private var records: [CountryRecord]
    @State private var selectedCountry: Country?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chrome: ChromeVisibility
    @AppStorage("mapDisplayMode") private var mapDisplayModeRaw = MapDisplayMode.color.rawValue
    @AppStorage("mapVisitedOnly") private var visitedOnly = false
    @Environment(\.colorScheme) private var colorScheme

    private var displayMode: MapDisplayMode { MapDisplayMode(rawValue: mapDisplayModeRaw) ?? .color }

    private var displayModeBinding: Binding<MapDisplayMode> {
        Binding(get: { displayMode }, set: { mapDisplayModeRaw = $0.rawValue })
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            InteractiveWorldMap(
                records: records,
                displayMode: displayMode,
                visitedOnly: visitedOnly,
                isDarkMode: colorScheme == .dark
            ) { code in
                selectedCountry = CountryCatalog.byCode[code]
            }
            .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .padding(.leading, 10)
            .padding(.top, 8)

            VStack(alignment: .trailing, spacing: 8) {
                MapModeControls(baseStyle: displayModeBinding, visitedOnly: $visitedOnly, floating: true)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 12)
            .padding(.top, 8)
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $selectedCountry) { country in
            CountryDetailView(country: country)
        }
        .onAppear { chrome.isFABHidden = true }
        .onDisappear { chrome.isFABHidden = false }
    }
}

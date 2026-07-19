import SwiftUI
import MapKit

struct GlobeMapView: UIViewRepresentable {
    let summaries: [CountryMemorySummary]
    let homeCountryCode: String
    var selectedCode: String?
    var recenterToken = 0
    /// true: 平面の全世界地図(MKStandardMapConfiguration, 地域指定)。
    /// false: 宇宙から見た3D地球儀(MKImageryMapConfiguration, カメラ距離指定)。
    var isFlat = false
    let onSelectCode: (String) -> Void

    private enum Camera {
        // MapKitは「カメラが十分に遠い」ときだけ地球を球体(宇宙から見た地球)として描く。
        // 地球の外周(約40,000km)を大きく超える距離を初期値にして、確実に球体表示の領域に入れる。
        static let initialDistance: CLLocationDistance = 60_000_000
        static let minimumDistance: CLLocationDistance = 1_500_000
        // 上限を絞りすぎると球体に入る前にズームが止まるため、広めに取る。
        static let maximumDistance: CLLocationDistance = 90_000_000
    }

    final class GlobeMKMapView: MKMapView {
        var initialCamera: MKMapCamera?
        var initialRegion: MKCoordinateRegion?
        /// ユーザーが操作するまでは、ビューのサイズ変化(セーフエリア展開など)のたびに
        /// 初期カメラを適用し直す。リサイズ時にMapKitが表示領域を保とうとして
        /// ズーム倍率が狂うのを防ぐ。
        var userHasAdjustedCamera = false
        private var lastAppliedSize: CGSize = .zero

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.width > 0, !userHasAdjustedCamera, bounds.size != lastAppliedSize
            else { return }
            lastAppliedSize = bounds.size
            if let initialCamera {
                setCamera(initialCamera, animated: false)
            } else if let initialRegion {
                setRegion(initialRegion, animated: false)
            }
        }
    }

    /// 平面モードの初期表示範囲。住んでいる国を中心に、広く世界を見渡せる範囲にする。
    /// 注記: MKStandardMapConfiguration(Flyoverではない通常の地図)は仕様上、
    /// MKMapRect.worldを渡してもFlyover系のように地球全体まではズームアウトできない
    /// (Appleのドキュメント外の既知の制約)。無理に全世界を1枚に収めようとはせず、
    /// 十分広い範囲を初期表示にして、そこから先はユーザーが自由にズーム操作できるようにする。
    private static func flatWorldRegion(homeCountryCode: String) -> MKCoordinateRegion {
        let center = CountryCoordinates.coordinate(for: homeCountryCode)
            ?? CLLocationCoordinate2D(latitude: 20, longitude: 0)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 90))
    }

    func makeUIView(context: Context) -> GlobeMKMapView {
        let map = GlobeMKMapView()
        if isFlat {
            // 平面の世界地図。宇宙から見た球体と違い、地形の3D表現も傾きも不要で
            // MKStandardMapConfigurationだけで軽く描ける。
            map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
            map.overrideUserInterfaceStyle = .dark
            map.isPitchEnabled = false
            map.isRotateEnabled = false
            map.initialRegion = Self.flatWorldRegion(homeCountryCode: homeCountryCode)
        } else {
            // 宇宙から見た「球体の地球」はMKStandardMapConfigurationでは描画されない。
            // elevationStyle: .flatも試したが、それだと球体表示自体が崩れて平面の地図に
            // 戻ってしまうため不可(.realisticがFlyover=地球儀表示に必須)。
            // 代わりに他の箇所(オーバーレイ数・フィルタ処理)で描画負荷を減らす。
            map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            // 「宇宙に浮かぶ地球」の見た目に固定する(ライトモードでも夜側の配色)。
            map.overrideUserInterfaceStyle = .dark
            map.isRotateEnabled = true
            // 地形が平面なので、傾けても見た目のメリットがない上に3D描画コストだけが乗る。
            map.isPitchEnabled = false
            map.cameraZoomRange = MKMapView.CameraZoomRange(
                minCenterCoordinateDistance: Camera.minimumDistance,
                maxCenterCoordinateDistance: Camera.maximumDistance
            )
            map.initialCamera = homeCamera
        }
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.showsScale = false
        map.isZoomEnabled = true
        map.isScrollEnabled = true

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        map.addGestureRecognizer(tap)
        context.coordinator.mapView = map
        context.coordinator.onSelectCode = onSelectCode
        return map
    }

    func updateUIView(_ map: GlobeMKMapView, context: Context) {
        context.coordinator.onSelectCode = onSelectCode
        let signature = summaries
            .map { "\($0.country.code):\($0.relationship.rawValue)" }
            .sorted()
            .joined(separator: "|") + "|selected:\(selectedCode ?? "")"

        if context.coordinator.overlaySignature != signature {
            context.coordinator.overlaySignature = signature
            // 初回表示時、makeUIViewと同じ実行パス(タブ切り替えの1フレーム)で
            // 国境ポリゴンの追加まで同期的に行うと、その分だけ体感の固まりが伸びる。
            // 次のRunLoopに回すことで、まずは地図そのものの初期描画を先に走らせる。
            DispatchQueue.main.async { [self] in
                rebuildOverlays(on: map, coordinator: context.coordinator)
            }
        }

        if context.coordinator.recenterToken != recenterToken {
            context.coordinator.recenterToken = recenterToken
            let animated = !UIAccessibility.isReduceMotionEnabled
            if isFlat {
                map.setRegion(Self.flatWorldRegion(homeCountryCode: homeCountryCode), animated: animated)
            } else {
                map.setCamera(homeCamera, animated: animated)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private var homeCamera: MKMapCamera {
        let center = CountryCoordinates.coordinate(for: homeCountryCode)
            ?? CLLocationCoordinate2D(latitude: 20, longitude: 20)
        return MKMapCamera(lookingAtCenter: center, fromDistance: Camera.initialDistance, pitch: 0, heading: 0)
    }

    private func rebuildOverlays(on map: MKMapView, coordinator: Coordinator) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)
        coordinator.codeByPolygon.removeAll(keepingCapacity: true)
        coordinator.relationshipByPolygon.removeAll(keepingCapacity: true)
        coordinator.selectedCode = selectedCode

        let relationshipByCode = Dictionary(uniqueKeysWithValues: summaries.map { ($0.country.code, $0.relationship) })
        var overlays: [MKPolygon] = []
        var labels: [CountryLabelAnnotation] = []
        overlays.reserveCapacity(CountryBorders.polygonsByCode.values.reduce(0) { $0 + $1.count })

        for (code, polygons) in CountryBorders.polygonsByCode {
            let relationship = relationshipByCode[code] ?? .unvisited
            for polygon in polygons {
                coordinator.codeByPolygon[ObjectIdentifier(polygon)] = code
                coordinator.relationshipByPolygon[ObjectIdentifier(polygon)] = relationship
                overlays.append(polygon)
            }
            // 色がついている(=関係のある)国だけに国名ラベルを置く。全200か国近く出すと
            // 地球儀が文字で埋まってしまうため、意味のある国だけに絞る。
            if relationship != .unvisited,
               let mainland = polygons.max(by: { $0.boundingMapRect.width * $0.boundingMapRect.height < $1.boundingMapRect.width * $1.boundingMapRect.height }),
               let name = CountryCatalog.byCode[code]?.name {
                labels.append(CountryLabelAnnotation(coordinate: centroid(of: mainland), name: name))
            }
        }
        map.addOverlays(overlays, level: .aboveLabels)
        map.addAnnotations(labels)
    }

    /// ポリゴンを構成する頂点の単純平均を重心近似として使う(表示用途には十分な精度)。
    private func centroid(of polygon: MKPolygon) -> CLLocationCoordinate2D {
        let count = polygon.pointCount
        guard count > 0 else { return polygon.coordinate }
        let points = polygon.points()
        var sumX = 0.0
        var sumY = 0.0
        for i in 0..<count {
            sumX += points[i].x
            sumY += points[i].y
        }
        return MKMapPoint(x: sumX / Double(count), y: sumY / Double(count)).coordinate
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        weak var mapView: MKMapView?
        var onSelectCode: ((String) -> Void)?
        var codeByPolygon: [ObjectIdentifier: String] = [:]
        var relationshipByPolygon: [ObjectIdentifier: CountryRelationship] = [:]
        var overlaySignature = ""
        var selectedCode: String?
        var recenterToken = 0

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // レンダラー準備前にsetCamera/setRegionしても反映されないことがあるため、
            // 読み込み完了後に適用し直す。
            guard let globeMap = mapView as? GlobeMKMapView, !globeMap.userHasAdjustedCamera else { return }
            if let camera = globeMap.initialCamera {
                mapView.setCamera(camera, animated: false)
            } else if let region = globeMap.initialRegion {
                mapView.setRegion(region, animated: false)
            }
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // ジェスチャー起点の変更ならユーザー操作とみなし、初期カメラの再適用を止める。
            guard let globeMap = mapView as? GlobeMKMapView, !globeMap.userHasAdjustedCamera else { return }
            let recognizers = (mapView.subviews.first?.gestureRecognizers ?? []) + (mapView.gestureRecognizers ?? [])
            if recognizers.contains(where: { $0.state == .began || $0.state == .changed || $0.state == .ended }) {
                globeMap.userHasAdjustedCamera = true
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let labelAnnotation = annotation as? CountryLabelAnnotation else { return nil }
            let identifier = "countryLabel"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? CountryLabelAnnotationView
                ?? CountryLabelAnnotationView(annotation: labelAnnotation, reuseIdentifier: identifier)
            view.annotation = labelAnnotation
            view.configure(text: labelAnnotation.title ?? "")
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolygonRenderer(polygon: polygon)
            let identifier = ObjectIdentifier(polygon)
            let relationship = relationshipByPolygon[identifier] ?? .unvisited
            let code = codeByPolygon[identifier]
            renderer.fillColor = UIColor(relationship.color).withAlphaComponent(relationship == .unvisited ? 0.05 : 0.82)
            renderer.strokeColor = code == selectedCode ? .white : UIColor.white.withAlphaComponent(relationship == .unvisited ? 0.1 : 0.4)
            renderer.lineWidth = code == selectedCode ? 2.4 : (relationship == .lived ? 0.9 : 0.45)
            return renderer
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView, gesture.state == .ended else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)

            let polygons = mapView.overlays.compactMap { $0 as? MKPolygon }.sorted {
                $0.boundingMapRect.size.width * $0.boundingMapRect.size.height
                    < $1.boundingMapRect.size.width * $1.boundingMapRect.size.height
            }
            for polygon in polygons {
                guard polygon.boundingMapRect.contains(mapPoint),
                      let renderer = mapView.renderer(for: polygon) as? MKPolygonRenderer,
                      let path = renderer.path
                else { continue }
                if path.contains(renderer.point(for: mapPoint)), let code = codeByPolygon[ObjectIdentifier(polygon)] {
                    onSelectCode?(code)
                    return
                }
            }
        }
    }
}

/// 色のついた国の重心に置く、常時表示の国名ラベル用アノテーション。
private final class CountryLabelAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(coordinate: CLLocationCoordinate2D, name: String) {
        self.coordinate = coordinate
        self.title = name
    }
}

/// 「光感」のある国名ラベル。白文字に淡い青の発光(シャドウ)を重ねて、
/// 大気のリムライトと同じトーンで馴染ませる。
private final class CountryLabelAnnotationView: MKAnnotationView {
    private let label = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        isEnabled = false
        collisionMode = .rectangle

        var font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        if let serifDescriptor = font.fontDescriptor.withDesign(.serif) {
            font = UIFont(descriptor: serifDescriptor, size: 12)
        }
        label.font = font
        label.textColor = .white
        label.textAlignment = .center
        label.layer.shadowColor = UIColor(red: 0.55, green: 0.8, blue: 1, alpha: 1).cgColor
        label.layer.shadowRadius = 4
        label.layer.shadowOpacity = 0.9
        label.layer.shadowOffset = .zero
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String) {
        label.text = text
        label.sizeToFit()
        let size = CGSize(width: label.bounds.width + 6, height: label.bounds.height + 2)
        bounds = CGRect(origin: .zero, size: size)
        label.frame = bounds
        // 塗りの中心より少し上に浮かせて、国の色と重ならないようにする。
        centerOffset = CGPoint(x: 0, y: -16)
    }
}

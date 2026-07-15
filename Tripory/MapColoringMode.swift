import MapKit
import SwiftUI
import UIKit

/// ホーム画面・全画面マップで切り替えられる下地の表示スタイル。
enum MapDisplayMode: String, CaseIterable {
    /// 通常のカラー地図。
    case color
    /// 白黒モード。すべての国を黒線で示し、記録した国だけ色をつける(塗り絵帳風)。
    case monochrome

    var label: LocalizedStringKey {
        switch self {
        case .color: return "カラー"
        case .monochrome: return "白黒"
        }
    }
}

/// 「白黒モード」: 地図の地形・海の色をニュートラルな下地に均し、
/// すべての国を黒い輪郭線で示したうえで、記録した国の色(ティール/オレンジ)だけが目立つようにする表示モード。
enum MapColoringMode {
    /// 指定した経度範囲を覆う下地ポリゴン。国のポリゴンより先に(下に)追加する。
    /// 経度180度をまたぐ1枚のポリゴンはMapKitで正しく描画されないため、範囲を渡して分割できるようにしている。
    static func washPolygon(minLon: Double = -180, maxLon: Double = 180) -> MKPolygon {
        let coords = [
            CLLocationCoordinate2D(latitude: 85, longitude: minLon),
            CLLocationCoordinate2D(latitude: 85, longitude: maxLon),
            CLLocationCoordinate2D(latitude: -85, longitude: maxLon),
            CLLocationCoordinate2D(latitude: -85, longitude: minLon),
        ]
        return MKPolygon(coordinates: coords, count: coords.count)
    }

    /// 経度180度を超える範囲の1枚のポリゴンはMapKitで正しく描画されないため、
    /// 90度以下の帯に分割して下地ポリゴンを作る。
    static func washPolygons(minLon: Double, maxLon: Double) -> [MKPolygon] {
        let maxSpan = 90.0
        var result: [MKPolygon] = []
        var lon = minLon
        while lon < maxLon - 0.0001 {
            let next = min(lon + maxSpan, maxLon)
            result.append(washPolygon(minLon: lon, maxLon: next))
            lon = next
        }
        return result
    }

    /// ダークモードでは白黒モードの下地・輪郭を反転させる(黒地に白線)。
    static func style(_ renderer: MKPolygonRenderer, isDarkMode: Bool) {
        renderer.fillColor = isDarkMode
            ? UIColor(red: 0.08, green: 0.08, blue: 0.085, alpha: 0.95)
            : UIColor(red: 0.93, green: 0.91, blue: 0.87, alpha: 0.9)
        renderer.strokeColor = .clear
        renderer.lineWidth = 0
    }

    /// 記録のない国の輪郭線。塗り絵帳のように、すべての国の境界を線で示す。
    /// ダークモードでは黒地に白線になるよう反転させる。
    static func borderStyle(_ renderer: MKPolygonRenderer, lineWidth: CGFloat, isDarkMode: Bool) {
        renderer.fillColor = .clear
        renderer.strokeColor = isDarkMode ? .white : .black
        renderer.lineWidth = lineWidth
    }
}

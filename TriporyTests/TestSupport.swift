import Foundation
import SwiftData
import UIKit
@testable import Tripory

enum TestSupport {
    /// テスト同士が干渉しないよう、毎回メモリ上に新しいストアを作る。
    @MainActor
    static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: CountryRecord.self, Trip.self, TripStop.self, HomeCountryPeriod.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// dayCountがCalendar.currentを使うため、日付生成も同じ暦・タイムゾーンに合わせる。
    static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: string) else {
            preconditionFailure("テスト用の日付文字列が不正です: \(string)")
        }
        return date
    }

    /// 指定した「ピクセル数」ちょうどの単色JPEGを作る(圧縮・写真まわりのテスト用)。
    /// scale=1で描くので、実行端末の解像度倍率に結果が左右されない。
    @MainActor
    static func jpegData(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            // 単色だとJPEGが縮みすぎて圧縮量の検証にならないため、細かい模様を描く。
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            for x in stride(from: 0, to: width, by: 7) {
                UIColor(hue: x / max(width, 1), saturation: 0.9, brightness: 0.9, alpha: 1).setFill()
                context.fill(CGRect(x: x, y: 0, width: 3, height: height))
            }
        }
        guard let data = image.jpegData(compressionQuality: 1) else {
            preconditionFailure("テスト用画像の生成に失敗しました")
        }
        return data
    }

    /// 旅を1件組み立ててコンテキストへ挿入する。stopsは (国コード, 開始日, 終了日) の並び。
    @MainActor
    @discardableResult
    static func insertTrip(
        into context: ModelContext,
        title: String = "テスト旅行",
        stops: [(code: String, start: String, end: String?)],
        photoData: Data? = nil
    ) -> Trip {
        let trip = Trip(title: title)
        context.insert(trip)
        for (index, stop) in stops.enumerated() {
            let record = TripStop(
                order: index,
                countryCode: stop.code,
                startDate: date(stop.start),
                endDate: stop.end.map { date($0) },
                photos: photoData.map { [$0] } ?? []
            )
            record.trip = trip
            context.insert(record)
        }
        return trip
    }
}

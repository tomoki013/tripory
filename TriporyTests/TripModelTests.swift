import Foundation
import Testing
@testable import Tripory

@MainActor
@Suite("旅と訪問先の日数・並び")
struct TripModelTests {

    // MARK: - TripStop.dayCount

    @Test("終了日がなければ1日として数える")
    func dayCountWithoutEndDate() {
        let stop = TripStop(order: 0, countryCode: "FR", startDate: TestSupport.date("2025-05-02"))
        #expect(stop.dayCount == 1)
    }

    @Test("同じ日に始まって終わる旅は1日")
    func dayCountSameDay() {
        let stop = TripStop(
            order: 0,
            countryCode: "FR",
            startDate: TestSupport.date("2025-05-02"),
            endDate: TestSupport.date("2025-05-02")
        )
        #expect(stop.dayCount == 1)
    }

    @Test("開始日と終了日の両端を含めて数える")
    func dayCountInclusive() {
        let stop = TripStop(
            order: 0,
            countryCode: "FR",
            startDate: TestSupport.date("2025-05-02"),
            endDate: TestSupport.date("2025-05-07")
        )
        #expect(stop.dayCount == 6)
    }

    @Test("終了日が開始日より前でも1日を下回らない")
    func dayCountNeverBelowOne() {
        let stop = TripStop(
            order: 0,
            countryCode: "FR",
            startDate: TestSupport.date("2025-05-07"),
            endDate: TestSupport.date("2025-05-02")
        )
        #expect(stop.dayCount == 1)
    }

    // MARK: - Trip

    @Test("合計日数は訪問先ごとの日数の合計")
    func totalDaysSumsStops() throws {
        let context = try TestSupport.makeContext()
        let trip = TestSupport.insertTrip(into: context, stops: [
            (code: "FR", start: "2019-05-02", end: "2019-05-07"), // 6日
            (code: "IT", start: "2019-05-08", end: "2019-05-10"), // 3日
        ])
        #expect(trip.totalDays == 9)
    }

    @Test("訪問先はorder順に並ぶ(挿入順に依存しない)")
    func sortedStopsFollowsOrder() throws {
        let context = try TestSupport.makeContext()
        let trip = Trip(title: "周遊")
        context.insert(trip)
        for (order, code) in [(2, "ES"), (0, "FR"), (1, "IT")] {
            let stop = TripStop(order: order, countryCode: code, startDate: TestSupport.date("2019-05-02"))
            stop.trip = trip
            context.insert(stop)
        }
        #expect(trip.sortedStops.map(\.countryCode) == ["FR", "IT", "ES"])
    }

    @Test("開始日は最初の訪問先、終了日は最後の訪問先から取る")
    func startAndEndDate() throws {
        let context = try TestSupport.makeContext()
        let trip = TestSupport.insertTrip(into: context, stops: [
            (code: "FR", start: "2019-05-02", end: "2019-05-07"),
            (code: "IT", start: "2019-05-08", end: "2019-05-10"),
        ])
        #expect(trip.startDate == TestSupport.date("2019-05-02"))
        #expect(trip.endDate == TestSupport.date("2019-05-10"))
    }

    @Test("最後の訪問先に終了日がなければ開始日を終了日として扱う")
    func endDateFallsBackToStartDate() throws {
        let context = try TestSupport.makeContext()
        let trip = TestSupport.insertTrip(into: context, stops: [
            (code: "FR", start: "2019-05-02", end: "2019-05-07"),
            (code: "IT", start: "2019-05-08", end: nil),
        ])
        #expect(trip.endDate == TestSupport.date("2019-05-08"))
    }

    @Test("訪問先のない旅は日付を持たず、合計0日")
    func emptyTripHasNoDates() throws {
        let context = try TestSupport.makeContext()
        let trip = Trip(title: "空の旅")
        context.insert(trip)
        #expect(trip.startDate == nil)
        #expect(trip.endDate == nil)
        #expect(trip.totalDays == 0)
        #expect(trip.countries.isEmpty)
    }

    @Test("国の並びと経路の文字列は訪問順になる")
    func countriesAndRouteDescription() throws {
        let context = try TestSupport.makeContext()
        let trip = TestSupport.insertTrip(into: context, stops: [
            (code: "FR", start: "2019-05-02", end: nil),
            (code: "IT", start: "2019-05-08", end: nil),
        ])
        let names = trip.countries.map(\.name)
        #expect(names.count == 2)
        #expect(trip.routeDescription == names.joined(separator: " → "))
    }

    @Test("同じ国を2回訪れる旅も両方の訪問先を保持する")
    func sameCountryTwiceInOneTrip() throws {
        let context = try TestSupport.makeContext()
        let trip = TestSupport.insertTrip(into: context, stops: [
            (code: "FR", start: "2019-05-02", end: "2019-05-03"),
            (code: "IT", start: "2019-05-04", end: nil),
            (code: "FR", start: "2019-05-05", end: nil),
        ])
        #expect(trip.sortedStops.count == 3)
        #expect(trip.totalDays == 4)
    }
}

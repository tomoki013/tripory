import Foundation
import SwiftData
import Testing
@testable import Tripory

@MainActor
@Suite("共通Trip保存フロー")
struct TripSaveServiceTests {
    private func input(_ code: String, _ date: String = "2025-01-01") -> TripStopInput {
        TripStopInput(countryCode: code, startDate: TestSupport.date(date), endDate: nil, photos: [])
    }

    private func save(
        in context: ModelContext,
        editing trip: Trip? = nil,
        stops: [TripStopInput]
    ) throws -> TripSaveOutcome {
        try TripSaveService.save(
            context: context,
            editingTrip: trip,
            title: "テスト旅行",
            suggestedTitle: "旅行",
            note: "",
            heroPhotoData: nil,
            stops: stops,
            homeCountryCode: "JP"
        )
    }

    @Test("既存国に過去日付のTripを追加しても新規国にならない")
    func backdatedExistingCountryIsNotNew() throws {
        let context = try TestSupport.makeContext()
        _ = try save(in: context, stops: [input("GR", "2025-01-01")])
        let result = try save(in: context, stops: [input("GR", "2024-01-01")])
        #expect(result.result.newlyVisitedCountryCodes.isEmpty)
    }

    @Test("初めての国と複数の初訪問国を返す")
    func detectsMultipleNewCountries() throws {
        let context = try TestSupport.makeContext()
        let result = try save(in: context, stops: [input("FR"), input("BE"), input("BE")])
        #expect(result.result.newlyVisitedCountryCodes == Set(["FR", "BE"]))
        #expect(result.result.addedCountryCodes == Set(["FR", "BE"]))
        #expect(result.reveals.count == 2)
    }

    @Test("編集で追加された初訪問国だけを返す")
    func editAddsOnlyNewCountry() throws {
        let context = try TestSupport.makeContext()
        let initial = try save(in: context, stops: [input("FR")])
        let trip = try #require(context.model(for: initial.result.tripID) as? Trip)
        let edited = try save(in: context, editing: trip, stops: [input("FR"), input("BE")])
        #expect(edited.result.newlyVisitedCountryCodes == Set(["BE"]))
        #expect(edited.result.addedCountryCodes == Set(["BE"]))
        #expect(edited.result.removedCountryCodes.isEmpty)
        #expect(!edited.result.isNewTrip)
    }

    @Test("編集で削除した国を結果へ含める")
    func editReportsRemovedCountry() throws {
        let context = try TestSupport.makeContext()
        let initial = try save(in: context, stops: [input("FR"), input("BE")])
        let trip = try #require(context.model(for: initial.result.tripID) as? Trip)
        let edited = try save(in: context, editing: trip, stops: [input("FR")])
        #expect(edited.result.removedCountryCodes == Set(["BE"]))
        #expect(edited.result.newlyVisitedCountryCodes.isEmpty)
        #expect(context.record(for: "BE").status == .none)
    }

    @Test("同一日の複数訪問でも国コードは重複しない")
    func sameDayVisitsAreDeduplicated() throws {
        let context = try TestSupport.makeContext()
        let result = try save(in: context, stops: [input("FR"), input("FR")])
        #expect(result.result.newlyVisitedCountryCodes == Set(["FR"]))
        #expect(try context.fetchCount(FetchDescriptor<TripStop>()) == 2)
    }

    @Test("入力検証失敗では保存もRevealも行わない")
    func validationFailureDoesNotSaveOrReveal() throws {
        let context = try TestSupport.makeContext()
        #expect(throws: TripSaveError.self) { try save(in: context, stops: []) }
        #expect(try context.fetchCount(FetchDescriptor<Trip>()) == 0)
        let coordinator = TripFlowCoordinator()
        #expect(coordinator.revealPayload == nil)
    }

    @Test("保存結果を渡した入口に依存せずCoordinatorが同じRevealを開始する")
    func coordinatorUsesSaveResultWithoutRecalculation() throws {
        let context = try TestSupport.makeContext()
        let outcome = try save(in: context, stops: [input("IS")])
        let coordinator = TripFlowCoordinator()
        coordinator.accept(outcome)
        #expect(coordinator.revealPayload?.countries.map(\.country.code) == ["IS"])
        #expect(coordinator.completeReveal()?.eventID == outcome.result.eventID)
        #expect(coordinator.completeReveal() == nil)
    }
}

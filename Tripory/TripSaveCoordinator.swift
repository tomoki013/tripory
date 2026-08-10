import Foundation
import Observation
import SwiftData

struct TripStopInput {
    let countryCode: String
    let startDate: Date
    let endDate: Date?
    let photos: [Data]
}

struct TripSaveResult {
    let eventID: UUID
    let tripID: PersistentIdentifier
    let newlyVisitedCountryCodes: Set<String>
    let addedCountryCodes: Set<String>
    let removedCountryCodes: Set<String>
    let isNewTrip: Bool
}

struct TripSaveOutcome {
    let result: TripSaveResult
    let reveals: [NewCountryReveal]
    let visitedCountryCount: Int
}

enum TripSaveService {
    @MainActor
    static func save(
        context: ModelContext,
        editingTrip: Trip?,
        title: String,
        suggestedTitle: String,
        note: String,
        heroPhotoData: Data?,
        stops: [TripStopInput],
        homeCountryCode: String
    ) throws -> TripSaveOutcome {
        guard !stops.isEmpty else { throw TripSaveError.noStops }
        let allExistingStops = try context.fetch(FetchDescriptor<TripStop>())
        let previouslyVisitedCodes = Set(allExistingStops.map(\.countryCode))
        let previousTripCodes = Set(editingTrip?.stops.map(\.countryCode) ?? [])
        let nextCodes = Set(stops.map(\.countryCode))
        let newlyVisited = nextCodes.subtracting(previouslyVisitedCodes)
        let isNewTrip = editingTrip == nil

        let trip = editingTrip ?? Trip()
        if isNewTrip { context.insert(trip) }
        for stop in trip.stops { context.delete(stop) }
        trip.title = title.trimmingCharacters(in: .whitespaces).isEmpty
            ? suggestedTitle : title.trimmingCharacters(in: .whitespaces)
        trip.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.heroPhotoData = heroPhotoData

        for (index, input) in stops.enumerated() {
            let stop = TripStop(
                order: index,
                countryCode: input.countryCode,
                startDate: input.startDate,
                endDate: input.endDate,
                photos: input.photos
            )
            stop.trip = trip
            context.insert(stop)
            context.record(for: input.countryCode).status = .visited
        }

        let removed = previousTripCodes.subtracting(nextCodes)
        context.revertStatusIfOrphaned(codes: removed, homeCountryCode: homeCountryCode)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        let records = try context.fetch(FetchDescriptor<CountryRecord>())
        let count = records.filter { $0.status.countsAsVisited && $0.code != homeCountryCode }.count
        let reveals = newlyVisited.compactMap { code -> NewCountryReveal? in
            guard let country = CountryCatalog.byCode[code] else { return nil }
            let photo = stops.first(where: { $0.countryCode == code })?.photos.first ?? heroPhotoData
            return NewCountryReveal(country: country, coverPhotoData: photo)
        }.sorted { $0.country.name.localizedStandardCompare($1.country.name) == .orderedAscending }

        return TripSaveOutcome(
            result: TripSaveResult(
                eventID: UUID(),
                tripID: trip.persistentModelID,
                newlyVisitedCountryCodes: newlyVisited,
                addedCountryCodes: nextCodes.subtracting(previousTripCodes),
                removedCountryCodes: removed,
                isNewTrip: isNewTrip
            ),
            reveals: reveals,
            visitedCountryCount: count
        )
    }
}

enum TripSaveError: Error { case noStops }

struct AddTripRequest: Identifiable {
    let id = UUID()
    let presetCountryCode: String?
}

@MainActor
@Observable
final class TripFlowCoordinator {
    var addRequest: AddTripRequest?
    var revealPayload: NewCountriesRevealPayload?
    private var pendingResult: TripSaveResult?

    func presentNewTrip(presetCountryCode: String? = nil) {
        addRequest = AddTripRequest(presetCountryCode: presetCountryCode)
    }

    func accept(_ outcome: TripSaveOutcome) {
        guard !outcome.result.newlyVisitedCountryCodes.isEmpty else { return }
        pendingResult = outcome.result
        revealPayload = NewCountriesRevealPayload(countries: outcome.reveals, totalCount: outcome.visitedCountryCount)
    }

    func completeReveal() -> TripSaveResult? {
        let result = pendingResult
        pendingResult = nil
        revealPayload = nil
        return result
    }
}

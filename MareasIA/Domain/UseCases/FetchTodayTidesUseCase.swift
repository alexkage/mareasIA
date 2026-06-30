import Foundation

protocol FetchTodayTidesUseCase {
    func execute(for city: City) async throws -> DailyTideData
}

final class FetchTodayTidesUseCaseImpl: FetchTodayTidesUseCase {
    private let tideRepository: TideRepository

    init(tideRepository: TideRepository) {
        self.tideRepository = tideRepository
    }

    func execute(for city: City) async throws -> DailyTideData {
        try await tideRepository.fetchTodayTides(for: city)
    }
}

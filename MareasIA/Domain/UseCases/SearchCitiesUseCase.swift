import Foundation

protocol SearchCitiesUseCase {
    func execute(query: String) async throws -> [City]
}

final class SearchCitiesUseCaseImpl: SearchCitiesUseCase {
    private let cityRepository: CityRepository

    init(cityRepository: CityRepository) {
        self.cityRepository = cityRepository
    }

    func execute(query: String) async throws -> [City] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            return []
        }
        return try await cityRepository.searchCities(query: trimmedQuery)
    }
}

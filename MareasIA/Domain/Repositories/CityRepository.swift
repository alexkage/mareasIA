import Foundation

protocol CityRepository {
    func searchCities(query: String) async throws -> [City]
}

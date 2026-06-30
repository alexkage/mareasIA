import Foundation

// MARK: - DTOs

private struct GeocodingResponse: Decodable {
    let results: [GeocodingResult]?
}

private struct GeocodingResult: Decodable {
    let name: String
    let country: String?
    let latitude: Double
    let longitude: Double
}

// MARK: - API Service

protocol CityAPIClient {
    func searchCities(query: String) async throws -> [City]
}

final class GeocodingAPIClient: CityAPIClient {
    func searchCities(query: String) async throws -> [City] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            .init(name: "name", value: query),
            .init(name: "count", value: "8"),
            .init(name: "language", value: "es"),
            .init(name: "format", value: "json")
        ]

        guard let url = components.url else {
            throw TideRepositoryError.invalidData
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw TideRepositoryError.networkError
        }

        let decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        return (decoded.results ?? []).map {
            City(
                name: $0.name,
                country: $0.country,
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }
    }
}

// MARK: - Repository Implementation

final class DefaultCityRepository: CityRepository {
    private let apiClient: CityAPIClient

    init(apiClient: CityAPIClient) {
        self.apiClient = apiClient
    }

    func searchCities(query: String) async throws -> [City] {
        try await apiClient.searchCities(query: query)
    }
}

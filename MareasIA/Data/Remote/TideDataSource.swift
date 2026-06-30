import Foundation

// MARK: - DTOs

private struct StormglassSeaLevelResponse: Decodable {
    let data: [StormglassSeaLevelPoint]
}

private struct StormglassSeaLevelPoint: Decodable {
    let time: String
    let sg: Double
}

private struct StormglassExtremesResponse: Decodable {
    let data: [StormglassExtremePoint]
}

private struct StormglassExtremePoint: Decodable {
    let time: String
    let height: Double
    let type: String
}

// MARK: - API Service

protocol TideAPIClient {
    func fetchTodayTides(latitude: Double, longitude: Double) async throws -> DailyTideData
}

final class StormglassAPIClient: TideAPIClient {
    private var apiKey: String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let key = plist["STORMGLASS_API_KEY"] as? String,
            !key.isEmpty,
            key != "YOUR_STORMGLASS_API_KEY"
        else {
            return ""
        }
        return key
    }

    #if DEBUG
    var testAPIKeyOverride: String?
    #endif

    func fetchTodayTides(latitude: Double, longitude: Double) async throws -> DailyTideData {
        let (start, end) = todayDateRange()
        let lat = String(latitude)
        let lng = String(longitude)

        async let seaLevelData = request(
            path: "/v2/tide/sea-level/point",
            queryItems: [
                .init(name: "lat", value: lat),
                .init(name: "lng", value: lng),
                .init(name: "start", value: start),
                .init(name: "end", value: end)
            ]
        )
        async let extremesData = request(
            path: "/v2/tide/extremes/point",
            queryItems: [
                .init(name: "lat", value: lat),
                .init(name: "lng", value: lng),
                .init(name: "start", value: start),
                .init(name: "end", value: end)
            ]
        )

        let seaLevel = try JSONDecoder().decode(StormglassSeaLevelResponse.self, from: try await seaLevelData)
        let extremes = try JSONDecoder().decode(StormglassExtremesResponse.self, from: try await extremesData)

        let points = parseSeaLevelData(seaLevel.data)
        let events = parseExtremesData(extremes.data)

        guard !points.isEmpty else { throw TideRepositoryError.invalidData }

        return DailyTideData(points: points, events: events)
    }

    private func request(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        #if DEBUG
        if let testAPIKeyOverride {
            return testAPIKeyOverride.data(using: .utf8) ?? Data()
        }
        #endif

        let effectiveKey = apiKey
        guard !effectiveKey.isEmpty else { throw TideRepositoryError.missingAPIKey }

        var components = URLComponents(string: "https://api.stormglass.io\(path)")!
        components.queryItems = queryItems

        guard let url = components.url else { throw TideRepositoryError.invalidData }

        var request = URLRequest(url: url)
        request.setValue(effectiveKey, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TideRepositoryError.networkError }

        switch http.statusCode {
        case 200:
            return data
        case 401, 403:
            throw TideRepositoryError.unauthorized
        default:
            throw TideRepositoryError.networkError
        }
    }

    private func parseSeaLevelData(_ data: [StormglassSeaLevelPoint]) -> [TidePoint] {
        data.compactMap { item -> TidePoint? in
            guard let date = parseDate(item.time) else { return nil }
            return TidePoint(time: date, height: item.sg)
        }.sorted(by: { $0.time < $1.time })
    }

    private func parseExtremesData(_ data: [StormglassExtremePoint]) -> [TideEvent] {
        data.compactMap { item -> TideEvent? in
            guard let date = parseDate(item.time) else { return nil }
            let kind: TideEvent.Kind = item.type == "high" ? .high : .low
            return TideEvent(time: date, height: item.height, kind: kind)
        }.sorted(by: { $0.time < $1.time })
    }

    private func parseDate(_ value: String) -> Date? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = parser.date(from: value) {
            return date
        }

        let fallbackParser = ISO8601DateFormatter()
        fallbackParser.formatOptions = [.withInternetDateTime]
        return fallbackParser.date(from: value)
    }

    private func todayDateRange() -> (start: String, end: String) {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!.addingTimeInterval(-1)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        return (formatter.string(from: startDate), formatter.string(from: endDate))
    }
}

// MARK: - Repository Implementation

final class DefaultTideRepository: TideRepository {
    private let apiClient: TideAPIClient

    init(apiClient: TideAPIClient) {
        self.apiClient = apiClient
    }

    func fetchTodayTides(for city: City) async throws -> DailyTideData {
        try await apiClient.fetchTodayTides(latitude: city.latitude, longitude: city.longitude)
    }
}

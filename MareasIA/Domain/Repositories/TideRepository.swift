import Foundation

protocol TideRepository {
    func fetchTodayTides(for city: City) async throws -> DailyTideData
}

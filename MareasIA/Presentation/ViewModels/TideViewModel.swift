import SwiftUI

@MainActor
final class TideViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var suggestions: [City] = []
    @Published var selectedCity: City?

    @Published var tidePoints: [TidePoint] = []
    @Published var tideEvents: [TideEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let searchCitiesUseCase: SearchCitiesUseCase
    private let fetchTidesUseCase: FetchTodayTidesUseCase
    private var searchTask: Task<Void, Never>?

    init(
        searchCitiesUseCase: SearchCitiesUseCase,
        fetchTidesUseCase: FetchTodayTidesUseCase
    ) {
        self.searchCitiesUseCase = searchCitiesUseCase
        self.fetchTidesUseCase = fetchTidesUseCase
    }

    func initialize() async {
        if selectedCity == nil {
            let defaultCity = City(
                name: "Vigo",
                country: "Spain",
                latitude: 42.2406,
                longitude: -8.7207
            )
            selectCity(defaultCity)
            await loadTides(for: defaultCity)
        }
    }

    func searchCity(_ query: String) async {
        searchTask?.cancel()
        searchTask = Task {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedQuery.count >= 2 else {
                suggestions = []
                return
            }

            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                suggestions = try await searchCitiesUseCase.execute(query: trimmedQuery)
            } catch is CancellationError {
                // Ignore cancellation
            } catch {
                suggestions = []
            }
        }
    }

    func selectCity(_ city: City) {
        selectedCity = city
        searchText = city.name
        errorMessage = nil
    }

    func loadTides(for city: City) async {
        isLoading = true
        errorMessage = nil

        do {
            let dailyTides = try await fetchTidesUseCase.execute(for: city)
            tidePoints = dailyTides.points
            tideEvents = dailyTides.events

            if dailyTides.points.isEmpty {
                errorMessage = "La API no devolvio datos para esta ciudad. Prueba otra localizacion costera."
            }
        } catch let error as TideRepositoryError {
            tidePoints = []
            tideEvents = []
            errorMessage = error.localizedDescription
        } catch {
            tidePoints = []
            tideEvents = []
            errorMessage = "Error desconocido: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

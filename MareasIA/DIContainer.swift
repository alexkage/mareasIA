import SwiftUI

// MARK: - Dependency Injection Container

final class DIContainer {
    static let shared = DIContainer()

    private init() {}

    // MARK: - Data Layer

    func makeCityAPIClient() -> CityAPIClient {
        GeocodingAPIClient()
    }

    func makeTideAPIClient() -> TideAPIClient {
        StormglassAPIClient()
    }

    // MARK: - Repository Layer

    func makeCityRepository() -> CityRepository {
        DefaultCityRepository(apiClient: makeCityAPIClient())
    }

    func makeTideRepository() -> TideRepository {
        DefaultTideRepository(apiClient: makeTideAPIClient())
    }

    // MARK: - Use Cases

    func makeSearchCitiesUseCase() -> SearchCitiesUseCase {
        SearchCitiesUseCaseImpl(cityRepository: makeCityRepository())
    }

    func makeFetchTodayTidesUseCase() -> FetchTodayTidesUseCase {
        FetchTodayTidesUseCaseImpl(tideRepository: makeTideRepository())
    }

    // MARK: - View Models

    func makeTideViewModel() -> TideViewModel {
        TideViewModel(
            searchCitiesUseCase: makeSearchCitiesUseCase(),
            fetchTidesUseCase: makeFetchTodayTidesUseCase()
        )
    }
}

@main
struct MareasIAApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: DIContainer.shared.makeTideViewModel())
        }
    }
}

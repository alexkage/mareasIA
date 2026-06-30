import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: TideViewModel

    init(viewModel: TideViewModel? = nil) {
        let vm = viewModel ?? TideViewModel(
            searchCitiesUseCase: SearchCitiesUseCaseImpl(
                cityRepository: DefaultCityRepository(
                    apiClient: GeocodingAPIClient()
                )
            ),
            fetchTidesUseCase: FetchTodayTidesUseCaseImpl(
                tideRepository: DefaultTideRepository(
                    apiClient: StormglassAPIClient()
                )
            )
        )
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CitySearchView(viewModel: viewModel)
                    TideChartView(
                        isLoading: viewModel.isLoading,
                        errorMessage: viewModel.errorMessage,
                        tidePoints: viewModel.tidePoints,
                        tideEvents: viewModel.tideEvents
                    )
                    TideDetailsView(tideEvents: viewModel.tideEvents)
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Mareas de hoy")
            .task {
                await viewModel.initialize()
            }
        }
    }
}

#Preview {
    ContentView()
}

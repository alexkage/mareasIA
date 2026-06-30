import SwiftUI

struct CitySearchView: View {
    @ObservedObject var viewModel: TideViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ciudad", systemImage: "mappin.and.ellipse")
                .font(.headline)

            TextField("Buscar ciudad...", text: $viewModel.searchText)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: viewModel.searchText) { _, newValue in
                    Task {
                        await viewModel.searchCity(newValue)
                    }
                }

            if !viewModel.suggestions.isEmpty {
                CitySearchResultsView(viewModel: viewModel)
            }

            if let selectedCity = viewModel.selectedCity {
                CitySelectionDisplayView(city: selectedCity) {
                    Task {
                        await viewModel.loadTides(for: selectedCity)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CitySearchResultsView: View {
    @ObservedObject var viewModel: TideViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.suggestions.prefix(5)) { city in
                Button {
                    viewModel.selectCity(city)
                    viewModel.suggestions = []
                    Task {
                        await viewModel.loadTides(for: city)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.name)
                                .foregroundStyle(.primary)
                            Text(city.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)

                if city.id != viewModel.suggestions.prefix(5).last?.id {
                    Divider()
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CitySelectionDisplayView: View {
    let city: City
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            Text("Seleccionada: \(city.subtitle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Actualizar", action: onRefresh)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

#Preview {
    @Previewable @State var viewModel = TideViewModel(
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
    
    CitySearchView(viewModel: viewModel)
}

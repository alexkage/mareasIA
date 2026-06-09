import Charts
import SwiftUI

struct ContentView: View {
    @State private var searchText = ""
    @State private var suggestions: [CitySuggestion] = []
    @State private var selectedCity: CitySuggestion?

    @State private var tidePoints: [TidePoint] = []
    @State private var tideEvents: [TideEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    citySelectorCard
                    chartCard
                    detailsCard
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Mareas de hoy")
            .task {
                if selectedCity == nil {
                    let defaultCity = CitySuggestion(
                        name: "Vigo",
                        country: "Spain",
                        latitude: 42.2406,
                        longitude: -8.7207
                    )
                    selectCity(defaultCity)
                    await loadTides(for: defaultCity)
                }
            }
            .task(id: searchText) {
                await autocompleteCity()
            }
        }
    }

    private var citySelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ciudad", systemImage: "mappin.and.ellipse")
                .font(.headline)

            TextField("Buscar ciudad...", text: $searchText)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions.prefix(5)) { city in
                        Button {
                            selectCity(city)
                            suggestions = []
                            Task {
                                await loadTides(for: city)
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

                        if city.id != suggestions.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let selectedCity {
                HStack {
                    Text("Seleccionada: \(selectedCity.subtitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Actualizar") {
                        Task { await loadTides(for: selectedCity) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Grafica diaria de marea", systemImage: "chart.xyaxis.line")
                .font(.headline)

            if isLoading {
                ProgressView("Cargando datos de mareas...")
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else if let errorMessage {
                emptyState(
                    icon: "exclamationmark.triangle",
                    title: "No se pudieron cargar las mareas",
                    message: errorMessage
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if tidePoints.isEmpty {
                emptyState(
                    icon: "water.waves",
                    title: "Sin datos",
                    message: "No hay informacion disponible para esta ubicacion."
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                Chart {
                    ForEach(tidePoints) { point in
                        AreaMark(
                            x: .value("Hora", point.time),
                            y: .value("Altura", point.height)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.35), Color.cyan.opacity(0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Hora", point.time),
                            y: .value("Altura", point.height)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    }

                    ForEach(tideEvents) { event in
                        PointMark(
                            x: .value("Hora", event.time),
                            y: .value("Altura", event.height)
                        )
                        .foregroundStyle(event.kind == .high ? .green : .orange)
                        .symbolSize(90)

                        RuleMark(x: .value("Hora", event.time))
                            .foregroundStyle(Color.secondary.opacity(0.25))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .annotation(position: .top, spacing: 4) {
                                Text(event.kind == .high ? "Alta" : "Baja")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    }
                }
                .chartYAxisLabel("Altura (m)", position: .leading)
                .frame(height: 260)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Detalle de pleamar y bajamar", systemImage: "list.bullet.rectangle")
                .font(.headline)

            if tideEvents.isEmpty {
                Text("No hay eventos de pleamar/bajamar disponibles para hoy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let highs = tideEvents.filter { $0.kind == .high }
                let lows = tideEvents.filter { $0.kind == .low }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Marea alta")
                        .font(.subheadline.weight(.semibold))
                    tideEventRows(highs)

                    Divider().padding(.vertical, 4)

                    Text("Marea baja")
                        .font(.subheadline.weight(.semibold))
                    tideEventRows(lows)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func tideEventRows(_ events: [TideEvent]) -> some View {
        if events.isEmpty {
            Text("Sin registros")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ForEach(events) { event in
                HStack {
                    Text(event.time, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
                    Spacer()
                    Text("\(event.height, specifier: "%.2f") m")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.body)
            }
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func selectCity(_ city: CitySuggestion) {
        selectedCity = city
        searchText = city.name
        errorMessage = nil
    }

    private func autocompleteCity() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            suggestions = []
            return
        }

        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            suggestions = try await TideService.searchCities(query: query)
        } catch is CancellationError {
            // Ignore cancellation from fast typing.
        } catch {
            suggestions = []
        }
    }

    private func loadTides(for city: CitySuggestion) async {
        isLoading = true
        errorMessage = nil

        do {
            let dailyTides = try await TideService.fetchTodayTides(latitude: city.latitude, longitude: city.longitude)
            tidePoints = dailyTides.points
            tideEvents = dailyTides.events

            if dailyTides.points.isEmpty {
                errorMessage = "La API no devolvio datos para esta ciudad. Prueba otra localizacion costera."
            }
        } catch {
            tidePoints = []
            tideEvents = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Domain Models

struct CitySuggestion: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let country: String?
    let latitude: Double
    let longitude: Double

    var subtitle: String {
        if let country, !country.isEmpty {
            return "\(name), \(country)"
        }
        return name
    }
}

struct TidePoint: Identifiable {
    let id = UUID()
    let time: Date
    let height: Double
}

struct TideEvent: Identifiable {
    enum Kind {
        case high
        case low
    }

    let id = UUID()
    let time: Date
    let height: Double
    let kind: Kind
}

struct DailyTideData {
    let points: [TidePoint]
    let events: [TideEvent]
}

// MARK: - API Service

enum TideService {
    static func searchCities(query: String) async throws -> [CitySuggestion] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            .init(name: "name", value: query),
            .init(name: "count", value: "8"),
            .init(name: "language", value: "es"),
            .init(name: "format", value: "json")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw TideServiceError.networkError
        }

        let decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        return (decoded.results ?? []).map {
            CitySuggestion(
                name: $0.name,
                country: $0.country,
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }
    }

    static func fetchTodayTides(latitude: Double, longitude: Double) async throws -> DailyTideData {
        let (start, end) = todayDateRange()
        let lat = String(latitude)
        let lng = String(longitude)

        async let seaLevelData = stormglassRequest(
            path: "/v2/tide/sea-level/point",
            queryItems: [
                .init(name: "lat", value: lat),
                .init(name: "lng", value: lng),
                .init(name: "start", value: start),
                .init(name: "end", value: end)
            ]
        )
        async let extremesData = stormglassRequest(
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

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackParser = ISO8601DateFormatter()
        fallbackParser.formatOptions = [.withInternetDateTime]

        func parseDate(_ value: String) -> Date? {
            parser.date(from: value) ?? fallbackParser.date(from: value)
        }

        let points = seaLevel.data.compactMap { item -> TidePoint? in
            guard let date = parseDate(item.time) else { return nil }
            return TidePoint(time: date, height: item.sg)
        }.sorted(by: { $0.time < $1.time })

        let events = extremes.data.compactMap { item -> TideEvent? in
            guard let date = parseDate(item.time) else { return nil }
            let kind: TideEvent.Kind = item.type == "high" ? .high : .low
            return TideEvent(time: date, height: item.height, kind: kind)
        }.sorted(by: { $0.time < $1.time })

        guard !points.isEmpty else { throw TideServiceError.invalidData }

        return DailyTideData(points: points, events: events)
    }

    #if DEBUG
    static var testAPIKeyOverride: String?
    #endif

    private static var stormglassAPIKey: String {
        #if DEBUG
        if let testAPIKeyOverride { return testAPIKeyOverride }
        #endif

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

    private static func todayDateRange() -> (start: String, end: String) {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!.addingTimeInterval(-1)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        return (formatter.string(from: startDate), formatter.string(from: endDate))
    }

    private static func stormglassRequest(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        guard !stormglassAPIKey.isEmpty else { throw TideServiceError.missingAPIKey }

        var components = URLComponents(string: "https://api.stormglass.io\(path)")!
        components.queryItems = queryItems

        guard let url = components.url else { throw TideServiceError.invalidData }

        var request = URLRequest(url: url)
        request.setValue(stormglassAPIKey, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TideServiceError.networkError }

        switch http.statusCode {
        case 200:
            return data
        case 401, 403:
            throw TideServiceError.unauthorized
        default:
            throw TideServiceError.networkError
        }
    }
}

enum TideServiceError: LocalizedError, Equatable {
    case networkError
    case invalidData
    case unauthorized
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Error de red al consultar la API de mareas."
        case .invalidData:
            return "Los datos recibidos no son validos."
        case .unauthorized:
            return "La API key de Stormglass no es valida."
        case .missingAPIKey:
            return "Falta la API key. Copia Secrets.example.plist a Secrets.plist e introduce tu clave."
        }
    }
}

// MARK: - API DTOs

private struct GeocodingResponse: Decodable {
    let results: [GeocodingResult]?
}

private struct GeocodingResult: Decodable {
    let name: String
    let country: String?
    let latitude: Double
    let longitude: Double
}

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

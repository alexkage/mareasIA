import Charts
import SwiftUI

struct TideChartView: View {
    let isLoading: Bool
    let errorMessage: String?
    let tidePoints: [TidePoint]
    let tideEvents: [TideEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Grafica diaria de marea", systemImage: "chart.xyaxis.line")
                .font(.headline)

            if isLoading {
                ProgressView("Cargando datos de mareas...")
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else if let errorMessage {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "No se pudieron cargar las mareas",
                    message: errorMessage
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if tidePoints.isEmpty {
                EmptyStateView(
                    icon: "water.waves",
                    title: "Sin datos",
                    message: "No hay informacion disponible para esta ubicacion."
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ChartContent(tidePoints: tidePoints, tideEvents: tideEvents)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ChartContent: View {
    let tidePoints: [TidePoint]
    let tideEvents: [TideEvent]

    var body: some View {
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

#Preview {
    TideChartView(
        isLoading: false,
        errorMessage: nil,
        tidePoints: [
            TidePoint(time: Date(), height: 1.5),
            TidePoint(time: Date().addingTimeInterval(3600), height: 1.8)
        ],
        tideEvents: [
            TideEvent(time: Date(), height: 2.0, kind: .high)
        ]
    )
}

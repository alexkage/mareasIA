import SwiftUI

struct TideDetailsView: View {
    let tideEvents: [TideEvent]

    var body: some View {
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
                    TideEventRowsView(events: highs)

                    Divider().padding(.vertical, 4)

                    Text("Marea baja")
                        .font(.subheadline.weight(.semibold))
                    TideEventRowsView(events: lows)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TideEventRowsView: View {
    let events: [TideEvent]

    var body: some View {
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
}

#Preview {
    TideDetailsView(tideEvents: [
        TideEvent(time: Date(), height: 2.0, kind: .high),
        TideEvent(time: Date().addingTimeInterval(3600), height: 0.5, kind: .low)
    ])
}

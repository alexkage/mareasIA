import Foundation

struct TidePoint: Identifiable {
    let id: UUID
    let time: Date
    let height: Double

    init(id: UUID = UUID(), time: Date, height: Double) {
        self.id = id
        self.time = time
        self.height = height
    }
}

struct TideEvent: Identifiable {
    enum Kind {
        case high
        case low
    }

    let id: UUID
    let time: Date
    let height: Double
    let kind: Kind

    init(id: UUID = UUID(), time: Date, height: Double, kind: Kind) {
        self.id = id
        self.time = time
        self.height = height
        self.kind = kind
    }
}

struct DailyTideData {
    let points: [TidePoint]
    let events: [TideEvent]

    init(points: [TidePoint], events: [TideEvent]) {
        self.points = points
        self.events = events
    }
}

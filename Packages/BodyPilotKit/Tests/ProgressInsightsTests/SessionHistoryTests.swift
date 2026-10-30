import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

@Test func sessionHistoryMergesAppAndHealthByDayNewestFirst() {
    let completed: [(day: Date, title: String?)] = [(day(2026, 10, 20), "Full body A"), (day(2026, 10, 22), nil)]
    let samples = [
        ActivitySample(id: "1", kind: .cycling, start: day(2026, 10, 22), minutes: 40, kcal: 320),
        ActivitySample(id: "2", kind: .walking, start: day(2026, 10, 25), minutes: 30),
    ]
    let days = SessionHistory.days(completed: completed, samples: samples, calendar: utc)
    #expect(days.map(\.day) == [day(2026, 10, 25), day(2026, 10, 22), day(2026, 10, 20)].map { utc.startOfDay(for: $0) })
    #expect(days[1].entries.map(\.title) == ["Séance", "Vélo"])
    #expect(days[1].entries[1].kcal == 320)
    #expect(days[1].entries[1].healthID == "1")
    #expect(days[1].entries[1].kind == .cycling)
    #expect(days[2].entries.first?.fromHealth == false)
    #expect(days[2].entries.first?.healthID == nil)
}

import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let planner = WeightImportPlanner(calendar: utc)

private func sample(_ id: String, _ date: Date, hour: Int = 7, _ kg: Double) -> WeightSample {
    WeightSample(id: id, date: utc.date(bySettingHour: hour, minute: 0, second: 0, of: date)!, kg: kg)
}

@Test func keepsTheFirstWeighingOfEachDay() {
    let samples = [
        sample("soir", day(2026, 10, 26), hour: 21, 86.4),
        sample("matin", day(2026, 10, 26), hour: 7, 85.6),
        sample("veille", day(2026, 10, 25), hour: 8, 85.9),
    ]
    let imported = planner.samplesToImport(samples, recordedDays: [])
    #expect(imported.map(\.id) == ["veille", "matin"])
}

@Test func neverOverridesADayAlreadyRecorded() {
    let samples = [
        sample("a", day(2026, 10, 26), 85.6),
        sample("b", day(2026, 10, 27), 85.4),
    ]
    let recorded: Set<Date> = [utc.startOfDay(for: day(2026, 10, 26))]
    #expect(planner.samplesToImport(samples, recordedDays: recorded).map(\.id) == ["b"])
}

@Test func skipsKnownSamplesAndImplausibleValues() {
    let samples = [
        sample("deja", day(2026, 10, 25), 85.9),
        sample("enfant", day(2026, 10, 26), 18),
        sample("ok", day(2026, 10, 27), 85.4),
    ]
    #expect(planner.samplesToImport(samples, recordedDays: [], knownIDs: ["deja"]).map(\.id) == ["ok"])
}

@Test func importingTwiceAddsNothing() {
    let samples = [sample("a", day(2026, 10, 26), 85.6), sample("b", day(2026, 10, 27), 85.4)]
    let first = planner.samplesToImport(samples, recordedDays: [])
    let recorded = Set(first.map { utc.startOfDay(for: $0.date) })
    #expect(planner.samplesToImport(samples, recordedDays: recorded, knownIDs: Set(first.map(\.id))).isEmpty)
}

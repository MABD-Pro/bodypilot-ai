import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private func time(_ dayOfMonth: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: dayOfMonth, hour: hour, minute: minute))!
}

private func session(_ dayOfMonth: Int, _ hour: Int, _ minute: Int = 0, kind: ActivityKind = .strength, minutes: Double = 50) -> ActivitySample {
    ActivitySample(id: "\(dayOfMonth)-\(hour)-\(minute)", kind: kind, start: time(dayOfMonth, hour, minute), minutes: minutes)
}

private let now = time(31, 9)

@Test func usualTimeIsTheMedianRoundedToAQuarter() {
    let samples = [session(20, 18, 5), session(22, 18, 40), session(24, 18, 20), session(27, 18, 35), session(29, 19, 0)]
    // Médiane 18 h 35 → 18 h 30.
    #expect(TrainingRhythm.usualStartMinute(samples, before: now, calendar: utc) == 18 * 60 + 30)
}

@Test func tooFewSessionsGiveNoRhythm() {
    let samples = [session(22, 18), session(24, 18), session(27, 18)]
    #expect(TrainingRhythm.usualStartMinute(samples, before: now, calendar: utc) == nil)
}

@Test func scatteredTimesGiveNoRhythm() {
    let samples = [session(20, 7), session(22, 12, 30), session(24, 18), session(27, 21), session(29, 9)]
    #expect(TrainingRhythm.usualStartMinute(samples, before: now, calendar: utc) == nil)
}

@Test func walksShortSessionsAndTodayDoNotCount() {
    let samples = [session(20, 18), session(22, 18), session(24, 18),
                   session(25, 7, kind: .walking), session(26, 7, minutes: 10), session(31, 7)]
    #expect(TrainingRhythm.usualStartMinute(samples, before: now, calendar: utc) == nil)
}

@Test func onlyTheFirstSessionOfADayCounts() {
    // Le 22 : séance à 18 h puis une autre à 21 h, une seule compte.
    let samples = [session(20, 18), session(22, 18), session(22, 21), session(24, 18), session(27, 18)]
    #expect(TrainingRhythm.usualStartMinute(samples, before: now, calendar: utc) == 18 * 60)
}

@Test func sessionReminderComesTwentyMinutesBefore() throws {
    let reminder = try #require(CoachReminders.session(usualStartMinute: 18 * 60 + 30, sessionTitle: "Full body A", isDone: false, now: now, calendar: utc))
    #expect(reminder.id == CoachReminders.sessionID)
    #expect(reminder.date == time(31, 18, 10))
    #expect(reminder.title == "Full body A")
    #expect(reminder.body.contains("18\u{00A0}h\u{00A0}30"))
}

@Test func noSessionReminderWhenDoneRestingOrPast() {
    #expect(CoachReminders.session(usualStartMinute: 18 * 60, sessionTitle: "Full body A", isDone: true, now: now, calendar: utc) == nil)
    #expect(CoachReminders.session(usualStartMinute: 18 * 60, sessionTitle: nil, isDone: false, now: now, calendar: utc) == nil)
    #expect(CoachReminders.session(usualStartMinute: 9 * 60, sessionTitle: "Full body A", isDone: false, now: now, calendar: utc) == nil)
    #expect(CoachReminders.session(usualStartMinute: nil, sessionTitle: "Full body A", isDone: false, now: now, calendar: utc) == nil)
}

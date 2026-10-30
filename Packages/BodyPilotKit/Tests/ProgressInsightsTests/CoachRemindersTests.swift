import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private func at(_ dayOfMonth: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: dayOfMonth, hour: hour, minute: minute))!
}

@Test func comebackReminderComesOnTheFourthQuietDay() {
    // Dernière note lundi 26 : la carte « On repart » apparaît vendredi 30, le rappel aussi.
    let reminders = CoachReminders.plan(lastActivity: day(2026, 10, 26), floorWeekUntil: nil, floorStrengthSessions: 0, now: day(2026, 10, 27), calendar: utc)
    #expect(reminders.map(\.id) == [CoachReminders.comebackID])
    #expect(reminders.first?.date == at(30, 18, 30))
}

@Test func aPastComebackReminderIsNotRescheduled() {
    // Déjà décroché : la carte est dans l'app, pas de nouveau rappel.
    #expect(CoachReminders.plan(lastActivity: day(2026, 10, 20), floorWeekUntil: nil, floorStrengthSessions: 0, now: day(2026, 10, 30), calendar: utc).isEmpty)
}

@Test func floorWeekReminderOnlyWhenSessionsAreMissing() {
    let end = FloorWeek.end(startingOn: day(2026, 10, 26), calendar: utc)
    let missing = CoachReminders.plan(lastActivity: day(2026, 10, 27), floorWeekUntil: end, floorStrengthSessions: 1, now: day(2026, 10, 28), calendar: utc)
    #expect(missing.map(\.id) == [CoachReminders.floorWeekID])
    // Jour 5 de la semaine plancher (vendredi 30) à 18 h.
    #expect(missing.first?.date == at(30, 18))
    #expect(missing.first?.body.hasPrefix("Une séance") == true)
    // Les deux séances faites : rien, et pas de rappel de décrochage pendant la semaine.
    #expect(CoachReminders.plan(lastActivity: day(2026, 10, 27), floorWeekUntil: end, floorStrengthSessions: 2, now: day(2026, 10, 28), calendar: utc).isEmpty)
}

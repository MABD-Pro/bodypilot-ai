import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let friday = day(2026, 10, 30)

private func daysBefore(_ count: Int) -> Date {
    utc.date(byAdding: .day, value: -count, to: friday)!
}

@Test func threeQuietDaysOfferAComeback() {
    let start = daysBefore(60)
    // Dernière note lundi : mardi, mercredi, jeudi sans rien.
    let comeback = Comeback.detect(activityDays: [daysBefore(10), daysBefore(4)], since: start, on: friday, calendar: utc)
    #expect(comeback?.quietDays == 3)
    #expect(comeback?.title == "3 jours sans nouvelles")
    // Deux jours seulement : rien.
    #expect(Comeback.detect(activityDays: [daysBefore(3)], since: start, on: friday, calendar: utc) == nil)
}

@Test func somethingNotedTodayEndsTheComeback() {
    #expect(Comeback.detect(activityDays: [daysBefore(20), friday], since: daysBefore(60), on: friday, calendar: utc) == nil)
}

@Test func aNewUserHasNotDroppedOut() {
    // Profil créé hier, rien noté : pas de décrochage.
    #expect(Comeback.detect(activityDays: [], since: daysBefore(1), on: friday, calendar: utc) == nil)
    // Profil créé il y a 5 jours sans rien noter depuis : 4 jours pleins.
    #expect(Comeback.detect(activityDays: [], since: daysBefore(5), on: friday, calendar: utc)?.quietDays == 4)
}

@Test func twoWeeksAwayIsWelcomedBack() {
    let comeback = Comeback.detect(activityDays: [daysBefore(20)], since: daysBefore(60), on: friday, calendar: utc)
    #expect(comeback?.title == "Content de te revoir")
}

@Test func floorWeekCountsWhatIsHeld() {
    // Semaine du lundi 26 au dimanche 1er : fin le lundi 2 novembre.
    let end = FloorWeek.end(startingOn: day(2026, 10, 26), calendar: utc)
    let progress = FloorWeekProgress.evaluate(
        until: end,
        strengthDays: [day(2026, 10, 26), day(2026, 10, 26), day(2026, 10, 29), day(2026, 10, 20)],
        proteinReachedDays: [day(2026, 10, 26), day(2026, 10, 27), day(2026, 10, 28)],
        weighIns: [day(2026, 10, 27)],
        on: friday,
        calendar: utc
    )
    #expect(progress.day == 5)
    // Deux séances le même jour comptent pour une ; celle d'avant la semaine ne compte pas.
    #expect(progress.strengthSessions == 2)
    #expect(progress.proteinDays == 3)
    #expect(progress.weighedIn)
    #expect(!progress.isHeld)
    #expect(progress.message.hasPrefix("Chaque case compte"))
}

@Test func floorWeekHeldIsCelebrated() {
    let end = FloorWeek.end(startingOn: day(2026, 10, 26), calendar: utc)
    let days = (26...29).map { day(2026, 10, $0) }
    let progress = FloorWeekProgress.evaluate(until: end, strengthDays: days, proteinReachedDays: days, weighIns: [days[0]], on: friday, calendar: utc)
    #expect(progress.isHeld)
    #expect(progress.message.hasPrefix("Plancher tenu"))
}

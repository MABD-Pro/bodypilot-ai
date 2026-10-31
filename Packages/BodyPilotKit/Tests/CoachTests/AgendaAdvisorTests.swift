import BodyPilotCore
import Foundation
import Testing
@testable import Coach

private let today = day(2026, 10, 31)

private func at(_ hour: Int, _ minute: Int = 0) -> Date {
    utc.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
}

private func event(_ title: String, _ start: (Int, Int), _ end: (Int, Int), location: String? = nil) -> AgendaEvent {
    AgendaEvent(title: title, start: at(start.0, start.1), end: at(end.0, end.1), location: location)
}

@Test func freeSlotIsTheFirstGapLongEnoughForTheSession() throws {
    let events = [event("Réunion", (8, 0), (12, 15)), event("Point client", (13, 0), (18, 30))]
    let advice = AgendaAdvisor.advice(events: events, now: at(7), sessionMinutes: 45, calendar: utc)
    // 7 h – 8 h fait 60 min : c'est le premier créneau.
    let slot = try #require(advice.freeSlot)
    #expect(slot.start == at(7))
    #expect(slot.duration == 45 * 60)
    #expect(advice.shortOnTimeMinutes == nil)
}

@Test func emptyAgendaSuggestsNothing() {
    let advice = AgendaAdvisor.advice(events: [], now: at(7), sessionMinutes: 45, calendar: utc)
    #expect(advice.isEmpty)
}

@Test func fullDayProposesTheLongestBreak() {
    let events = [event("Atelier", (6, 0), (12, 0)), event("Atelier", (12, 35), (17, 0)), event("Revue", (17, 20), (22, 0))]
    let advice = AgendaAdvisor.advice(events: events, now: at(6), sessionMinutes: 45, calendar: utc)
    #expect(advice.freeSlot == nil)
    #expect(advice.shortOnTimeMinutes == 35)
    #expect(advice.suggestions == [.shortOnTime])
}

@Test func breakShorterThanFifteenMinutesProposesNothing() {
    let events = [event("Garde", (6, 0), (14, 0)), event("Garde", (14, 10), (22, 0))]
    let advice = AgendaAdvisor.advice(events: events, now: at(6), sessionMinutes: 45, calendar: utc)
    #expect(advice.shortOnTimeMinutes == nil)
}

@Test func pastEventsAndTimeDoNotCount() throws {
    // À 15 h, la réunion du matin est passée : l'après-midi est libre.
    let events = [event("Réunion", (8, 0), (12, 0)), event("Call", (16, 0), (17, 0))]
    let advice = AgendaAdvisor.advice(events: events, now: at(15), sessionMinutes: 45, calendar: utc)
    #expect(try #require(advice.freeSlot).start == at(15))
}

@Test func restaurantInTheEveningMeansDinnerOut() throws {
    let advice = AgendaAdvisor.advice(events: [event("Dîner au resto avec Léa", (20, 0), (22, 30))], now: at(9), sessionMinutes: 45, calendar: utc)
    let eatingOut = try #require(advice.eatingOut)
    #expect(eatingOut.slot == .dinner)
    #expect(advice.suggestions.contains(.eatingOut))
}

@Test func businessLunchIsLunchOut() {
    let advice = AgendaAdvisor.advice(events: [event("Déjeuner d’affaires", (12, 30), (14, 0))], now: at(9), sessionMinutes: 45, calendar: utc)
    #expect(advice.eatingOut?.slot == .lunch)
}

@Test func restaurantFoundInTheLocation() {
    let advice = AgendaAdvisor.advice(events: [event("Anniversaire de Sam", (19, 30), (23, 0), location: "Pizzeria Napoli, Lyon")], now: at(9), sessionMinutes: 45, calendar: utc)
    #expect(advice.eatingOut?.slot == .dinner)
}

@Test func finishedRestaurantIsIgnored() {
    let advice = AgendaAdvisor.advice(events: [event("Brunch", (11, 0), (13, 0))], now: at(14), sessionMinutes: 45, calendar: utc)
    #expect(advice.eatingOut == nil)
}

@Test func trainOrFlightMeansTravel() {
    let advice = AgendaAdvisor.advice(events: [event("Train Paris → Lyon", (7, 30), (9, 30))], now: at(6), sessionMinutes: 45, calendar: utc)
    #expect(advice.travelEvent == "Train Paris → Lyon")
    #expect(advice.suggestions.first == .traveling)
}

@Test func trainingIsNotATrain() {
    let advice = AgendaAdvisor.advice(events: [event("Entraînement de foot", (18, 0), (19, 30))], now: at(9), sessionMinutes: 45, calendar: utc)
    #expect(advice.travelEvent == nil)
}

@Test func allDayTripCountsAsTravelButNotAsBusyTime() throws {
    let trip = AgendaEvent(title: "Séminaire à Bordeaux", start: utc.startOfDay(for: today), end: utc.date(byAdding: .day, value: 1, to: utc.startOfDay(for: today))!, isAllDay: true)
    let advice = AgendaAdvisor.advice(events: [trip, event("Atelier", (9, 0), (12, 0))], now: at(7), sessionMinutes: 45, calendar: utc)
    #expect(advice.travelEvent != nil)
    #expect(try #require(advice.freeSlot).start == at(7))
}

@Test func otherDaysAreIgnored() {
    let tomorrow = AgendaEvent(title: "Vol pour Rome", start: at(7).addingTimeInterval(86_400), end: at(9).addingTimeInterval(86_400))
    #expect(AgendaAdvisor.advice(events: [tomorrow], now: at(7), sessionMinutes: 45, calendar: utc).isEmpty)
}

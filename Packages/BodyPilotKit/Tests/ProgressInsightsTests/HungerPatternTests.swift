import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let today = day(2026, 10, 31)

private func note(daysAgo: Int, hour: Int, _ level: HungerLevel = .hungry) -> HungerNote {
    let date = utc.date(bySettingHour: hour, minute: 10, second: 0, of: utc.date(byAdding: .day, value: -daysAgo, to: today)!)!
    return HungerNote(date: date, level: level)
}

@Test func afternoonHungerThreeDaysMakesLunchFuller() throws {
    let notes = [note(daysAgo: 1, hour: 16), note(daysAgo: 3, hour: 17), note(daysAgo: 6, hour: 15), note(daysAgo: 2, hour: 9)]
    let pattern = try #require(HungerPatterns.pattern(notes, on: today, calendar: utc))
    #expect(pattern.window == .afternoon)
    #expect(pattern.window.mealBefore == .lunch)
    #expect(pattern.days == 3)
    #expect(pattern.message.contains("déjeuner"))
}

@Test func twoDaysAreNotAHabit() {
    let notes = [note(daysAgo: 1, hour: 16), note(daysAgo: 3, hour: 17)]
    #expect(HungerPatterns.pattern(notes, on: today, calendar: utc) == nil)
}

@Test func hungerSameDayCountsOnce() {
    let notes = [note(daysAgo: 1, hour: 15), note(daysAgo: 1, hour: 16), note(daysAgo: 1, hour: 18)]
    #expect(HungerPatterns.pattern(notes, on: today, calendar: utc) == nil)
}

@Test func peckishDoesNotCount() {
    let notes = (1...5).map { note(daysAgo: $0, hour: 16, .peckish) }
    #expect(HungerPatterns.pattern(notes, on: today, calendar: utc) == nil)
}

@Test func oldNotesAreIgnored() {
    let notes = [note(daysAgo: 15, hour: 16), note(daysAgo: 16, hour: 16), note(daysAgo: 20, hour: 16)]
    #expect(HungerPatterns.pattern(notes, on: today, calendar: utc) == nil)
}

@Test func lateNightCountsForTheEveningBefore() throws {
    // 23 h puis 1 h du matin le lendemain : la même soirée.
    let notes = [note(daysAgo: 3, hour: 23), note(daysAgo: 2, hour: 1), note(daysAgo: 5, hour: 22), note(daysAgo: 7, hour: 21)]
    let pattern = try #require(HungerPatterns.pattern(notes, on: today, calendar: utc))
    #expect(pattern.window == .evening)
    #expect(pattern.window.mealBefore == .dinner)
    #expect(pattern.days == 3)
}

@Test func windowsMapToTheMealBefore() {
    #expect(HungerWindow(hour: 10).mealBefore == .breakfast)
    #expect(HungerWindow(hour: 12).mealBefore == .breakfast)
    #expect(HungerWindow(hour: 16).mealBefore == .lunch)
    #expect(HungerWindow(hour: 2).mealBefore == .dinner)
}

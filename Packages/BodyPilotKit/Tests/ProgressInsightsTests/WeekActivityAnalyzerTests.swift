import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let analyzer = WeekActivityAnalyzer(calendar: utc)
// 26/10/2026 est un lundi ; le jeudi 29 au soir, la semaine est en cours.
private let thursdayEvening = utc.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 21))!

private func at(_ dayOfMonth: Int, _ hour: Int) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: dayOfMonth, hour: hour))!
}

@Test func theWeekShowsHealthActivitiesAndCheckedSessions() {
    let samples = [
        ActivitySample(id: "run", kind: .running, start: at(27, 7), minutes: 40, kcal: 420),
        ActivitySample(id: "lastweek", kind: .cycling, start: at(25, 10), minutes: 90, kcal: 800),
    ]
    let week = analyzer.week(of: thursdayEvening, samples: samples, completed: [(at(26, 0), "Full body A")], sessionMinutes: 45)
    #expect(week.days.count == 7)
    #expect(week.entries.map(\.title) == ["Course", "Full body A"])
    #expect(week.minutesPerDay[0] == 45)
    #expect(week.minutesPerDay[1] == 40)
    #expect(week.summary == "2 activités · 1 h 25 · 420 kcal")
}

@Test func aSessionRecordedByTheWatchIsNotShownTwice() {
    let samples = [ActivitySample(id: "w", kind: .strength, start: at(26, 18), minutes: 42, kcal: 250)]
    let week = analyzer.week(of: thursdayEvening, samples: samples, completed: [(at(26, 0), "Full body A")], sessionMinutes: 45)
    #expect(week.entries.count == 1)
    #expect(week.entries.first?.fromHealth == true)
}

@Test func onlyRealSessionsCountForConsistency() {
    let samples = [
        ActivitySample(id: "walk", kind: .walking, start: at(27, 12), minutes: 60),
        ActivitySample(id: "short", kind: .running, start: at(28, 7), minutes: 10),
        ActivitySample(id: "bike", kind: .cycling, start: at(29, 7), minutes: 50),
    ]
    let days = analyzer.sessionDays(completedDays: [at(26, 0)], samples: samples)
    #expect(days == [utc.startOfDay(for: at(26, 0)), utc.startOfDay(for: at(29, 0))])
}

@Test func anEmptyWeekSaysSo() {
    #expect(analyzer.week(of: thursdayEvening, samples: [], completed: [], sessionMinutes: 45).summary == "Rien d'enregistré cette semaine pour l'instant.")
    #expect(WeekActivityAnalyzer.duration(65) == "1 h 05")
}

@Test func checkedSessionsKeepTheirFamily() {
    let week = analyzer.week(of: thursdayEvening, samples: [], completed: [(at(26, 0), "Cardio et marche en côte"), (at(27, 0), "Marche tranquille")], sessionMinutes: 45)
    #expect(week.entries.map(\.kind) == [.walking, .cardio])
}

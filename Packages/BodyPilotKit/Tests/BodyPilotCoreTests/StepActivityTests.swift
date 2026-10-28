import Foundation
import Testing
@testable import BodyPilotCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()
private let today = utc.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!

private func days(_ counts: [Int]) -> [DailySteps] {
    let start = utc.startOfDay(for: today)
    return counts.enumerated().map { index, steps in
        DailySteps(day: utc.date(byAdding: .day, value: index - counts.count, to: start)!, steps: steps)
    }
}

@Test func averageNeedsSevenMeasuredDaysAndSkipsEmptyOnes() {
    #expect(StepActivity.average(days([6_000, 0, 6_000, 6_000, 6_000, 6_000, 6_000]), before: today, calendar: utc) == nil)
    #expect(StepActivity.average(days([6_000, 0, 6_000, 6_000, 6_000, 6_000, 6_000, 9_000]), before: today, calendar: utc) == 45_000.0 / 7)
}

@Test func todayDoesNotCountInTheAverage() {
    var steps = days(Array(repeating: 8_000, count: 10))
    steps.append(DailySteps(day: utc.startOfDay(for: today), steps: 500))
    #expect(StepActivity.average(steps, before: today, calendar: utc) == 8_000)
}

@Test func workoutStepsAreNotCountedTwice() {
    let steps = days(Array(repeating: 12_000, count: 7))
    let run = ActivitySample(id: "run", kind: .running, start: steps[0].day.addingTimeInterval(8 * 3_600), minutes: 30, kcal: 350)
    let strength = ActivitySample(id: "gym", kind: .strength, start: steps[1].day.addingTimeInterval(8 * 3_600), minutes: 60, kcal: 300)
    // 30 min de course ≈ 4 800 pas, déjà comptés en calories ; la musculation ne retire rien.
    #expect(StepActivity.average(steps, excluding: [run, strength], before: today, calendar: utc) == (12_000.0 * 7 - 4_800) / 7)
}

@Test func displayedAverageIsRoundedToHundreds() {
    #expect(StepActivity.displayed(6_529) == 6_500)
    #expect(StepActivity.displayed(6_551) == 6_600)
}

@Test func goalRisesByAThousandUpToTheAgeZone() {
    #expect(StepActivity.goal(averageSteps: 6_100, age: 35) == 7_500)
    #expect(StepActivity.goal(averageSteps: 6_000, age: 35) == 7_000)
    #expect(StepActivity.goal(averageSteps: 9_800, age: 35) == 10_000)
    #expect(StepActivity.goal(averageSteps: 9_800, age: 65) == 8_000)
    #expect(StepActivity.goal(averageSteps: nil, age: 65) == 6_000)
}

@Test func stepsMapToActivityLevels() {
    #expect(ActivityLevel(averageSteps: 4_000) == .sedentary)
    #expect(ActivityLevel(averageSteps: 7_499) == .light)
    #expect(ActivityLevel(averageSteps: 7_500) == .moderate)
    #expect(ActivityLevel(averageSteps: 12_000) == .active)
}

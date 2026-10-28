import Testing
@testable import BodyPilotCore

@Test func cycleWeekOutsideTheCycleIsClamped() {
    #expect(CycleWeek(program: .crossfit, number: 0).number == 1)
    #expect(CycleWeek(program: .hyrox, number: 40).number == TrainingCycle.weeks)
    #expect(CycleWeek(program: .crossfit, number: 40).phase == 3)
}

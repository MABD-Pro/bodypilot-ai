import Testing
@testable import Coach

@Test func homeScreenAnswersExactlyThreeQuestions() {
    #expect(DailyQuestion.allCases == [.whatToEat, .whichWorkout, .amIProgressing])
}

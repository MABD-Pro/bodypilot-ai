import Foundation
import Testing
@testable import BodyPilotCore

private let start = Date(timeIntervalSince1970: 1_000)

private var twoExercises: SessionProgress {
    SessionProgress(steps: [
        SessionStep(name: "Squat", detail: "3 × 5", sets: 3, restSeconds: 150),
        SessionStep(name: "Gainage", detail: "2 × 45 s", sets: 2, restSeconds: 0),
    ])
}

@Test func setDoneStartsTheRestAndTheNextSet() {
    let progress = twoExercises.completingSet(at: start)
    #expect(progress.stepIndex == 0)
    #expect(progress.setNumber == 2)
    #expect(progress.restEndsAt == start.addingTimeInterval(150))
}

@Test func lastSetMovesToTheNextExercise() {
    var progress = twoExercises
    for _ in 0..<3 { progress = progress.completingSet(at: start) }
    #expect(progress.current?.name == "Gainage")
    #expect(progress.setNumber == 1)
    #expect(progress.restEndsAt == start.addingTimeInterval(150))
    #expect(abs(progress.fractionDone - 0.6) < 0.0001)
}

@Test func noRestAfterTheLastSetOrWithoutRest() {
    var progress = twoExercises
    for _ in 0..<4 { progress = progress.completingSet(at: start) }
    #expect(progress.setNumber == 2)
    #expect(progress.restEndsAt == nil)
    progress = progress.completingSet(at: start)
    #expect(progress.isFinished)
    #expect(progress.restEndsAt == nil)
    #expect(progress.fractionDone == 1)
    #expect(progress.completingSet(at: start) == progress)
}

@Test func skippingAnExerciseClearsTheRest() {
    let progress = twoExercises.completingSet(at: start).skippingExercise()
    #expect(progress.current?.name == "Gainage")
    #expect(progress.setNumber == 1)
    #expect(progress.restEndsAt == nil)
    #expect(progress.next == nil)
}

import BodyPilotCore
import Testing
@testable import Coach

private let interpreter = CommandInterpreter()

private func parse(_ text: String) -> Set<QuickAdjustment> {
    interpreter.interpret(text)?.adjustments ?? []
}

@Test(arguments: [
    ("Je n'ai que 20 minutes", QuickAdjustment.shortOnTime),
    ("pas le temps aujourd'hui", .shortOnTime),
    ("Je suis crevé", .tired),
    ("J'ai très mal dormi", .tired),
    ("J'ai raté ma séance hier soir", .missedWorkout),
    ("Ce soir je mange au resto", .eatingOut),
    ("Dîner au Restaurant avec des collègues", .eatingOut),
    ("Je n'ai pas FAIM", .notHungry),
    ("j’ai mal au genou droit", .kneePain),
    ("Je pars en déplacement à Lyon", .traveling),
    ("Nuit à l'hôtel", .traveling),
])
func understandsCommonPhrases(text: String, expected: QuickAdjustment) {
    #expect(parse(text).contains(expected), "« \(text) »")
}

@Test func understandsSeveralThingsInOneSentence() {
    let result = interpreter.interpret("Je suis fatigué, j'ai 15 min et ce soir c'est resto")
    #expect(result?.adjustments == [.tired, .shortOnTime, .eatingOut])
    #expect(result?.availableMinutes == 15)
    #expect(result?.eatingOutSlot == .dinner)
    #expect(result?.tier == .deterministic)
}

@Test func ignoresUnrelatedOrAmbiguousPhrases() {
    #expect(parse("Quelle belle journée").isEmpty)
    #expect(parse("Je suis en train de cuisiner") == [])
    #expect(interpreter.interpret("Bonjour")?.isUnderstood == false)
}

@Test func restaurantMealFollowsTheWords() {
    #expect(interpreter.interpret("resto ce midi")?.eatingOutSlot == .lunch)
    #expect(interpreter.interpret("dîner au restaurant")?.eatingOutSlot == .dinner)
    #expect(interpreter.interpret("je mange au resto")?.eatingOutSlot == nil)
}

@Test func absurdDurationsAreNotTakenLiterally() {
    let result = interpreter.interpret("j'ai 500 min")
    #expect(result?.availableMinutes == nil)
}

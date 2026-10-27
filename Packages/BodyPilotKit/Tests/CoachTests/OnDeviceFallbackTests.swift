import AIRouter
import BodyPilotCore
import Testing
@testable import Coach

private struct StubModel: CommandLanguageModel {
    var draft: CommandDraft

    func draft(for text: String) async throws -> CommandDraft { draft }
}

private struct FailingModel: CommandLanguageModel {
    struct Failure: Error {}

    func draft(for text: String) async throws -> CommandDraft { throw Failure() }
}

private let withOnDevice = AIRouter(availableTiers: [.deterministic, .onDevice])

@Test func keywordsWinWithoutCallingTheModel() async {
    let interpreter = CommandInterpreter(router: withOnDevice, model: StubModel(draft: CommandDraft(adjustments: [.traveling])))
    let result = await interpreter.understand("Je suis crevé")
    #expect(result?.adjustments == [.tired])
    #expect(result?.tier == .deterministic)
}

@Test func modelTakesOverWhenKeywordsMissTheSentence() async {
    let interpreter = CommandInterpreter(router: withOnDevice, model: StubModel(draft: CommandDraft(adjustments: [.notHungry])))
    let result = await interpreter.understand("J'ai l'estomac noué depuis ce matin")
    #expect(result?.adjustments == [.notHungry])
    #expect(result?.tier == .onDevice)
}

@Test func modelAnswerIsCheckedLikeKeywords() async {
    let draft = CommandDraft(adjustments: [.tired], availableMinutes: 300, eatingOutSlot: .dinner)
    let interpreter = CommandInterpreter(router: withOnDevice, model: StubModel(draft: draft))
    let result = await interpreter.understand("Grosse journée, je suis lessivé")
    // 300 min est absurde, et un repas sans restaurant n'a pas de sens.
    #expect(result?.adjustments == [.tired])
    #expect(result?.availableMinutes == nil)
    #expect(result?.eatingOutSlot == nil)
}

@Test func modelMinutesImplyShortOnTime() async {
    let draft = CommandDraft(adjustments: [.eatingOut], availableMinutes: 25, eatingOutSlot: .lunch)
    let interpreter = CommandInterpreter(router: withOnDevice, model: StubModel(draft: draft))
    let result = await interpreter.understand("Déj d'équipe, et une petite demi-heure ensuite")
    #expect(result?.adjustments == [.eatingOut, .shortOnTime])
    #expect(result?.availableMinutes == 25)
    #expect(result?.eatingOutSlot == .lunch)
}

@Test func noOnDeviceTierMeansNoModelCall() async {
    let interpreter = CommandInterpreter(model: StubModel(draft: CommandDraft(adjustments: [.notHungry])))
    let result = await interpreter.understand("J'ai l'estomac noué depuis ce matin")
    #expect(result?.isUnderstood == false)
    #expect(result?.tier == .deterministic)
}

@Test func modelFailureFallsBackToNotUnderstood() async {
    let interpreter = CommandInterpreter(router: withOnDevice, model: FailingModel())
    let result = await interpreter.understand("J'ai l'estomac noué depuis ce matin")
    #expect(result?.isUnderstood == false)
}

@Test func overlongTextNeverReachesTheModel() async {
    let interpreter = CommandInterpreter(router: withOnDevice, model: StubModel(draft: CommandDraft(adjustments: [.notHungry])))
    let result = await interpreter.understand(String(repeating: "bla ", count: 100))
    #expect(result?.isUnderstood == false)
}

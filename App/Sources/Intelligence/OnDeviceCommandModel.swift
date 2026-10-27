import AIRouter
import BodyPilotCore
import Coach
import FoundationModels

/// Lecture d'une phrase libre par le modèle Apple embarqué : gratuit, hors ligne, rien ne quitte l'iPhone.
///
/// Utilisé seulement quand les mots-clés n'ont rien reconnu (voir `CommandInterpreter.understand`).
/// La disponibilité est vérifiée à l'exécution : sans Apple Intelligence, le niveau embarqué est retiré du routeur.
struct OnDeviceCommandModel: CommandLanguageModel {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    /// Interpréteur de l'app : mots-clés, puis modèle embarqué s'il est disponible.
    static func interpreter() -> CommandInterpreter {
        guard isAvailable else { return CommandInterpreter() }
        return CommandInterpreter(router: AIRouter(availableTiers: [.deterministic, .onDevice]), model: OnDeviceCommandModel())
    }

    private static let instructions = """
        Tu aides une app de coaching sportif et nutritionnel. L'utilisateur décrit sa journée en une phrase, en français.
        Indique seulement ce qu'il dit explicitement ou très clairement. En cas de doute, réponds faux.
        """

    func draft(for text: String) async throws -> CommandDraft {
        let session = LanguageModelSession(instructions: Self.instructions)
        let parsed = try await session.respond(to: text, generating: ParsedDay.self).content
        var adjustments: Set<QuickAdjustment> = []
        if parsed.shortOnTime { adjustments.insert(.shortOnTime) }
        if parsed.tired { adjustments.insert(.tired) }
        if parsed.missedWorkout { adjustments.insert(.missedWorkout) }
        if parsed.eatingOut { adjustments.insert(.eatingOut) }
        if parsed.notHungry { adjustments.insert(.notHungry) }
        if parsed.kneePain { adjustments.insert(.kneePain) }
        if parsed.traveling { adjustments.insert(.traveling) }
        if parsed.wantsToTrain { adjustments.insert(.wantsToTrain) }
        return CommandDraft(adjustments: adjustments, availableMinutes: parsed.availableMinutes, eatingOutSlot: parsed.eatingOutMeal?.slot)
    }
}

@Generable
struct ParsedDay {
    @Guide(description: "Peu de temps pour s'entraîner aujourd'hui")
    var shortOnTime: Bool
    @Guide(description: "Fatigué, épuisé, a mal dormi, manque d'énergie")
    var tired: Bool
    @Guide(description: "A raté ou sauté sa séance de sport")
    var missedWorkout: Bool
    @Guide(description: "Mange au restaurant, chez quelqu'un ou à l'extérieur aujourd'hui")
    var eatingOut: Bool
    @Guide(description: "Peu ou pas d'appétit")
    var notHungry: Bool
    @Guide(description: "Douleur ou gêne au genou")
    var kneePain: Bool
    @Guide(description: "En déplacement, en voyage, loin de chez soi")
    var traveling: Bool
    @Guide(description: "A envie de faire du sport ou une séance aujourd'hui")
    var wantsToTrain: Bool
    @Guide(description: "Minutes disponibles pour l'entraînement, si un nombre est donné")
    var availableMinutes: Int?
    @Guide(description: "Repas pris à l'extérieur, s'il est précisé")
    var eatingOutMeal: Meal?

    @Generable
    enum Meal {
        case lunch
        case dinner

        var slot: MealSlot {
            switch self {
            case .lunch: .lunch
            case .dinner: .dinner
            }
        }
    }
}

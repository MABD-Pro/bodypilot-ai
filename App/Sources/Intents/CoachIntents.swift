import AppIntents
import BodyPilotCore
import Coach
import SwiftData

// Siri et Raccourcis : ajuster sa journée ou connaître son plan sans ouvrir l'app.
// Tout reste local : mots-clés, puis modèle embarqué si besoin, comme dans l'app.

enum AdjustmentOption: String, AppEnum {
    case shortOnTime
    case tired
    case missedWorkout
    case eatingOut
    case notHungry
    case kneePain
    case traveling
    case wantsToTrain

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Ajustement"
    static let caseDisplayRepresentations: [AdjustmentOption: DisplayRepresentation] = [
        .shortOnTime: DisplayRepresentation(title: "je n'ai que 20 minutes", image: .init(systemName: "timer")),
        .tired: DisplayRepresentation(title: "je suis fatigué", image: .init(systemName: "battery.25percent")),
        .missedWorkout: DisplayRepresentation(title: "j'ai raté ma séance", image: .init(systemName: "arrow.uturn.backward")),
        .eatingOut: DisplayRepresentation(title: "je mange au restaurant", image: .init(systemName: "fork.knife")),
        .notHungry: DisplayRepresentation(title: "je n'ai pas faim", image: .init(systemName: "leaf")),
        .kneePain: DisplayRepresentation(title: "j'ai mal au genou", image: .init(systemName: "bandage")),
        .traveling: DisplayRepresentation(title: "je pars en déplacement", image: .init(systemName: "suitcase.rolling")),
        .wantsToTrain: DisplayRepresentation(title: "j'ai envie de bouger", image: .init(systemName: "bolt.heart")),
    ]

    var adjustment: QuickAdjustment {
        switch self {
        case .shortOnTime: .shortOnTime
        case .tired: .tired
        case .missedWorkout: .missedWorkout
        case .eatingOut: .eatingOut
        case .notHungry: .notHungry
        case .kneePain: .kneePain
        case .traveling: .traveling
        case .wantsToTrain: .wantsToTrain
        }
    }
}

struct AdjustDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Ajuster ma journée"
    static let description: IntentDescription? = IntentDescription("Adapte le plan du jour : peu de temps, fatigue, restaurant, genou…")

    @Parameter(title: "Ajustement", requestValueDialog: "Qu'est-ce qui change aujourd'hui ?")
    var adjustment: AdjustmentOption

    init() {}

    init(adjustment: AdjustmentOption) {
        self.adjustment = adjustment
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let command = InterpretedCommand(adjustments: [adjustment.adjustment], tier: .deterministic)
        return .result(dialog: "\(CoachIntents.apply(command))")
    }
}

struct TellCoachIntent: AppIntent {
    static let title: LocalizedStringResource = "Dire au coach"
    static let description: IntentDescription? = IntentDescription("Décris ta journée en une phrase : « resto ce soir et j'ai 20 minutes ».")

    @Parameter(title: "Phrase", requestValueDialog: "Dis-moi ce qui change aujourd'hui.")
    var sentence: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let command = await OnDeviceCommandModel.interpreter().understand(sentence), command.isUnderstood else {
            return .result(dialog: "Je n'ai pas compris. Essaie « je mange au resto » ou « j'ai 15 minutes ».")
        }
        return .result(dialog: "\(CoachIntents.apply(command))")
    }
}

struct TodayPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Mon plan du jour"
    static let description: IntentDescription? = IntentDescription("Ce que tu manges, ta séance et ta tendance, en une réponse.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let plan = DayLogEditor.todayPlan(in: AppContainer.shared.mainContext) else {
            return .result(dialog: "Ouvre BodyPilot pour créer ton profil, puis redemande-moi.")
        }
        return .result(dialog: "\(CoachIntents.spoken(plan))")
    }
}

struct WorkoutDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "J'ai fait ma séance"
    static let description: IntentDescription? = IntentDescription("Coche la séance du jour pour suivre ta régularité.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppContainer.shared.mainContext
        let title = DayLogEditor.todayPlan(in: context).flatMap(\.training.workoutTitle)
        let log = DayLogEditor.todayLog(in: context)
        log.workoutDone = true
        log.doneWorkoutTitle = title
        try? context.save()
        return .result(dialog: "Bravo, séance cochée. La régularité, c'est ce qui fait les résultats.")
    }
}

@MainActor
enum CoachIntents {
    /// Enregistre l'ajustement dans le journal du jour et renvoie la confirmation à dire.
    static func apply(_ command: InterpretedCommand) -> String {
        let context = AppContainer.shared.mainContext
        DayLogEditor.apply(command, to: DayLogEditor.todayLog(in: context))
        try? context.save()
        var reply = "C'est noté : \(command.summary)."
        if let plan = DayLogEditor.todayPlan(in: context) {
            reply += " \(plan.headline)"
        }
        return reply
    }

    static func spoken(_ plan: TodayPlan) -> String {
        let training = switch plan.training.kind {
        case .workout(let workout): "Séance : \(workout.title), \(plan.training.estimatedMinutes) minutes."
        case .activeRest(let title, let minutes): "\(title), \(minutes) minutes."
        }
        let macros = plan.targets.macros
        return "\(plan.headline) \(training) Objectif : \(macros.kcal.frenchInteger) kcal, dont \(macros.proteinG.frenchInteger) g de protéines."
    }
}

struct BodyPilotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodayPlanIntent(),
            phrases: [
                "Mon plan du jour dans \(.applicationName)",
                "Quel est mon plan \(.applicationName)",
                "Qu'est-ce que je fais aujourd'hui avec \(.applicationName)",
            ],
            shortTitle: "Plan du jour",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: AdjustDayIntent(),
            phrases: [
                "Dis à \(.applicationName) : \(\.$adjustment)",
                "\(\.$adjustment) dans \(.applicationName)",
                "Ajuste ma journée dans \(.applicationName)",
            ],
            shortTitle: "Ajuster ma journée",
            systemImageName: "slider.horizontal.3"
        )
        AppShortcut(
            intent: TellCoachIntent(),
            phrases: [
                "Parle à \(.applicationName)",
                "Dis quelque chose à \(.applicationName)",
            ],
            shortTitle: "Dire au coach",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: WorkoutDoneIntent(),
            phrases: [
                "J'ai fait ma séance dans \(.applicationName)",
                "Séance terminée dans \(.applicationName)",
            ],
            shortTitle: "Séance faite",
            systemImageName: "checkmark.seal"
        )
    }
}

/// Les trois questions auxquelles l'écran principal doit répondre à l'ouverture.
///
/// Le coach orchestre Nutrition, Training et ProgressInsights via des protocoles
/// définis dans BodyPilotCore ; il ne dépend pas directement de ces modules.
public enum DailyQuestion: String, CaseIterable, Sendable {
    /// Que dois-je manger aujourd'hui ?
    case whatToEat
    /// Quel entraînement dois-je effectuer ?
    case whichWorkout
    /// Est-ce que je progresse vers mon objectif ?
    case amIProgressing
}

import BodyPilotCore
import Testing
@testable import Coach

private let all = Set(MealSlot.allCases)

@Test func aFullDebriefIsUnderstood() {
    let debrief = EveningDebriefParser.parse("Séance faite, pizza ce soir et je suis crevé", pendingSlots: [.dinner])
    #expect(debrief.workoutDone == true)
    #expect(debrief.meals == [.dinner: .hearty])
    #expect(debrief.tomorrow == [.tired])
    #expect(debrief.understoodLines == ["Séance faite", "Dîner : copieux", "Demain : fatigué"])
    #expect(debrief.coachReply.contains("sans compenser"))
}

@Test func aMissedSessionIsNotReadAsDone() {
    #expect(EveningDebriefParser.parse("j'ai pas fait ma séance", pendingSlots: []).workoutDone == false)
    #expect(EveningDebriefParser.parse("Pas eu le temps d'aller à la salle", pendingSlots: []).workoutDone == false)
    #expect(EveningDebriefParser.parse("raté le sport aujourd'hui", pendingSlots: []).workoutDone == false)
    #expect(EveningDebriefParser.parse("J'ai fait ma séance de muscu", pendingSlots: []).workoutDone == true)
    #expect(EveningDebriefParser.parse("j'ai couru 5 km", pendingSlots: []).workoutDone == true)
}

@Test func asPlannedFillsOnlyPendingMeals() {
    let debrief = EveningDebriefParser.parse("Tout comme prévu", pendingSlots: [.snack, .dinner])
    #expect(debrief.meals == [.snack: .asPlanned, .dinner: .asPlanned])
    #expect(debrief.workoutDone == nil)
}

@Test func aNamedMealWinsOverAsPlanned() {
    let debrief = EveningDebriefParser.parse("Repas comme prévu sauf un gros craquage au déjeuner", pendingSlots: all)
    #expect(debrief.meals[.lunch] == .veryHearty)
    #expect(debrief.meals[.dinner] == .asPlanned)
}

@Test func skippedAndLightMeals() {
    #expect(EveningDebriefParser.parse("j'ai sauté le dîner", pendingSlots: all).meals == [.dinner: .skipped])
    #expect(EveningDebriefParser.parse("mangé léger ce midi", pendingSlots: all).meals == [.lunch: .light])
}

@Test func nothingUnderstood() {
    let debrief = EveningDebriefParser.parse("Belle journée au bureau", pendingSlots: all)
    #expect(!debrief.isUnderstood)
    #expect(debrief.coachReply == "Noté. Bonne soirée.")
}

import Foundation
import BodyPilotCore
import Testing
@testable import Training

private let planner = TrainingPlanner(calendar: utc)
// 26/10/2026 est un lundi.
private let monday = day(2026, 10, 26)
private let tuesday = day(2026, 10, 27)

private func workout(_ day: TrainingDay) -> Workout? {
    if case .workout(let workout) = day.kind { return workout }
    return nil
}

@Test func threeDaysPerWeekAreSpreadOut() {
    #expect(TrainingPlanner.trainingWeekdays(daysPerWeek: 3) == [2, 4, 6])
    #expect(TrainingPlanner.trainingWeekdays(daysPerWeek: 9).count == 6)
}

@Test func trainingDayHasWorkoutWithinPreferredDuration() {
    let result = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())
    #expect(workout(result) != nil)
    #expect(result.estimatedMinutes <= 45)
}

@Test func theDayAfterStrengthIsCardioAndInclineWalk() throws {
    let result = planner.trainingDay(for: makeProfile(), on: tuesday, constraints: DayConstraints(lastStrengthDay: monday))
    let session = try #require(workout(result))
    #expect(session.title == "Cardio et marche en côte")
    #expect(!session.hasStrength)
    #expect(session.exercises.count == 2)
    #expect(result.estimatedMinutes <= 45 && result.estimatedMinutes >= 40)
    #expect(planner.options(for: makeProfile(), on: tuesday, constraints: DayConstraints(lastStrengthDay: monday)).reason.contains("48 h"))
    // Cardio continu et sans impact les jours de récupération, quel que soit le format du jour.
    for offset in 0..<8 {
        let date = try #require(utc.date(byAdding: .day, value: offset, to: tuesday))
        let yesterday = try #require(utc.date(byAdding: .day, value: -1, to: date))
        for equipment in Equipment.allCases {
            let recovery = try #require(workout(planner.trainingDay(for: makeProfile(equipment: equipment), on: date, constraints: DayConstraints(lastStrengthDay: yesterday))))
            #expect(!recovery.exercises.contains { $0.isHighImpact })
            #expect(recovery.exercises.allSatisfy { $0.sets == 1 && $0.restSeconds == 0 })
        }
    }
    let gym = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .gym), on: tuesday, constraints: DayConstraints(lastStrengthDay: monday))))
    #expect(gym.title == "Cardio et marche inclinée")
}

@Test func strengthComesBackAfterFortyEightHours() throws {
    let wednesday = day(2026, 10, 28)
    let result = planner.trainingDay(for: makeProfile(), on: wednesday, constraints: DayConstraints(lastWorkoutTitle: "Full body A", lastStrengthDay: monday))
    let session = try #require(workout(result))
    #expect(session.hasStrength)
    #expect(session.title == "Full body B")
}

@Test func everyDayHasASessionAndStrengthNeverFollowsStrength() throws {
    var last: Date?
    var title: String?
    var strengthDays = 0
    for offset in 0..<7 {
        let date = try #require(utc.date(byAdding: .day, value: offset, to: monday))
        let session = try #require(workout(planner.trainingDay(for: makeProfile(), on: date, constraints: DayConstraints(lastWorkoutTitle: title, lastStrengthDay: last))))
        if session.hasStrength {
            if let last { #expect(utc.dateComponents([.day], from: last, to: date).day ?? 0 >= 2) }
            last = date
            title = session.title
            strengthDays += 1
        }
    }
    // Lundi, mercredi, vendredi, dimanche : 4 séances de force sur 7 jours.
    #expect(strengthDays == 4)
}

@Test func twentyMinutesKeepsEssentialExercises() throws {
    let result = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(availableMinutes: 20))
    let session = try #require(workout(result))
    #expect(result.estimatedMinutes <= 20)
    #expect(session.exercises.count >= 3)
    #expect(session.exercises.filter { $0.priority == 1 }.count == 2)
}

@Test func gymSessionFitsInTwentyMinutes() {
    let profile = makeProfile(equipment: .gym)
    let result = planner.trainingDay(for: profile, on: monday, constraints: DayConstraints(availableMinutes: 20))
    #expect(result.estimatedMinutes <= 20)
}

@Test func tooLittleTimeBecomesAWalk() {
    let result = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(availableMinutes: 8))
    #expect(workout(result) == nil)
}

@Test func tiredRemovesImpactAndReducesVolume() throws {
    let normal = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())))
    let tired = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(lowEnergy: true))))
    #expect(!tired.exercises.contains { $0.isHighImpact })
    // Les séries baissent sans descendre sous 2 ; un effort continu reste en une fois.
    #expect(tired.exercises.allSatisfy { $0.sets >= 2 || $0.sets == 1 && $0.restSeconds == 0 })
    #expect(tired.exercises.map(\.sets).reduce(0, +) < normal.exercises.map(\.sets).reduce(0, +))
}

@Test func missedWorkoutIsNeverDoubled() {
    let missed = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(missedToday: true))
    #expect(workout(missed) == nil)
}

@Test func aMissedStrengthSessionIsProposedAgainTheNextDay() throws {
    // Force samedi, rien de fait lundi : mardi, la force revient.
    let result = planner.trainingDay(for: makeProfile(), on: tuesday, constraints: DayConstraints(lastWorkoutTitle: "Full body A", lastStrengthDay: day(2026, 10, 24)))
    #expect(try #require(workout(result)).title == "Full body B")
}

@Test func sessionsAlternateAThenB() {
    #expect(planner.nextWorkout(after: nil, for: makeProfile(), on: monday).title == "Full body A")
    #expect(planner.nextWorkout(after: "Full body A", for: makeProfile(), on: monday).title == "Full body B")
    #expect(planner.nextWorkout(after: "Full body B", for: makeProfile(), on: monday).title == "Full body A")
    #expect(TrainingPlanner.isStrengthSession("Full body B"))
    #expect(!TrainingPlanner.isStrengthSession("Cardio et marche en côte"))
}

@Test func kneePainRemovesEveryKneeLoadingExercise() throws {
    for equipment in Equipment.allCases {
        for date in [monday, day(2026, 10, 28)] {
            let result = planner.trainingDay(for: makeProfile(equipment: equipment), on: date, constraints: DayConstraints(kneePain: true))
            let session = try #require(workout(result))
            #expect(!session.exercises.contains { $0.loadsKnee || $0.isHighImpact })
            #expect(session.exercises.count >= 3)
            #expect(result.notes.contains { $0.contains("professionnel de santé") })
        }
    }
}

@Test func kneePainOnARecoveryDayKeepsTheWalkFlat() throws {
    let result = planner.trainingDay(for: makeProfile(), on: tuesday, constraints: DayConstraints(kneePain: true, lastStrengthDay: monday))
    let session = try #require(workout(result))
    #expect(!session.exercises.contains { $0.loadsKnee || $0.isHighImpact })
    #expect(session.exercises.contains { $0.name == "Marche à plat" })
}

@Test func travelingUsesBodyweightWithinThirtyMinutes() throws {
    let result = planner.trainingDay(for: makeProfile(sessionMinutes: 60, equipment: .gym), on: monday, constraints: DayConstraints(traveling: true))
    let session = try #require(workout(result))
    #expect(result.estimatedMinutes <= TrainingPlanner.travelMaxMinutes)
    let sessions = WorkoutCatalog.sessions(for: .bodyweight)
    let bodyweightNames = Set(sessions.flatMap { $0.exercises.map(\.name) }
        + WorkoutCatalog.cardio(for: .bodyweight).map(\.name) + WorkoutCatalog.incline(for: .bodyweight).map(\.name)
        + sessions.flatMap { WorkoutCatalog.accessories(after: $0.title, equipment: .bodyweight).map(\.name) } + [WorkoutCatalog.balance.name])
    #expect(session.exercises.allSatisfy { bodyweightNames.contains($0.name) })
}

@Test func swapCyclesThroughAlternativesThenBackToOriginal() throws {
    let base = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())))
    let first = try #require(base.exercises.first)
    #expect(first.alternatives.count >= 2)

    func name(afterSwaps count: Int) throws -> String {
        let result = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(exerciseSwaps: [first.key: count]))
        return try #require(workout(result)?.exercises.first).name
    }
    #expect(try name(afterSwaps: 1) == first.alternatives[0])
    #expect(try name(afterSwaps: 2) == first.alternatives[1])
    #expect(try name(afterSwaps: first.alternatives.count + 1) == first.name)
}

@Test func swapKeepsVolumeAndKey() throws {
    let base = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())))
    let target = base.exercises[1]
    let swapped = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(exerciseSwaps: [target.key: 1]))))
    let exercise = swapped.exercises[1]
    #expect(exercise.name != target.name)
    #expect(exercise.key == target.key)
    #expect(exercise.sets == target.sets && exercise.volume == target.volume && exercise.restSeconds == target.restSeconds)
    #expect(Array(swapped.exercises.dropFirst(2)) == Array(base.exercises.dropFirst(2)))
}

@Test func kneePainOverridesASwapThatLoadsTheKnee() throws {
    let base = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())))
    let squat = try #require(base.exercises.first { $0.loadsKnee })
    let constraints = DayConstraints(kneePain: true, exerciseSwaps: [squat.key: 1])
    let session = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: constraints)))
    let protected = try #require(session.exercises.first { $0.key == squat.key })
    #expect(protected.name == squat.kneeFriendlyAlternative)
    #expect(protected.alternatives.isEmpty)
}

@Test func everyCatalogExerciseHasDistinctAlternatives() {
    let all = WorkoutCatalog.sessions(for: .bodyweight) + WorkoutCatalog.sessions(for: .gym)
    for exercise in all.flatMap(\.exercises) {
        #expect(!exercise.alternatives.isEmpty, "\(exercise.name) sans variante")
        #expect(!exercise.alternatives.contains(exercise.name))
        #expect(Set(exercise.alternatives).count == exercise.alternatives.count)
    }
}

@Test func profileKeepsAtLeastOneUsualDay() {
    let profile = UserProfile(
        sex: .male, birthDate: day(1991, 1, 1), heightCm: 180, startWeightKg: 90, activity: .moderate, goal: .loseFat,
        trainingDaysPerWeek: 3, trainingWeekdays: [9, 0], sessionMinutes: 45, equipment: .bodyweight
    )
    #expect(profile.trainingWeekdays == [4])
    #expect(makeProfile(daysPerWeek: 3).trainingWeekdays == [2, 4, 6])
}

@Test(arguments: [Equipment.bodyweight, .gym], [45, 60])
func aSessionChainsStrengthCardioAndInclineWalk(equipment: Equipment, minutes: Int) throws {
    let profile = makeProfile(sessionMinutes: minutes, equipment: equipment)
    let result = planner.trainingDay(for: profile, on: monday, constraints: DayConstraints())
    let session = try #require(workout(result))
    let cardioNames = Set(WorkoutCatalog.cardio(for: equipment).map(\.name))
    let inclineNames = Set(WorkoutCatalog.incline(for: equipment).map(\.name))
    let sessions = WorkoutCatalog.sessions(for: equipment)
    let strengthNames = Set(sessions.flatMap { $0.exercises.map(\.name) } + sessions.flatMap { WorkoutCatalog.accessories(after: $0.title, equipment: equipment).map(\.name) })
    #expect(session.exercises.dropLast(2).allSatisfy { strengthNames.contains($0.name) })
    #expect(cardioNames.contains(session.exercises[session.exercises.count - 2].name))
    #expect(inclineNames.contains(session.exercises[session.exercises.count - 1].name))
    #expect(result.estimatedMinutes <= minutes)
    #expect(result.estimatedMinutes >= minutes - 3)
}

@Test func cardioChangesFromOneSessionToTheNext() throws {
    let wednesday = day(2026, 10, 28)
    let first = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())))
    let second = try #require(workout(planner.trainingDay(for: makeProfile(), on: wednesday, constraints: DayConstraints())))
    #expect(first.exercises[first.exercises.count - 2].name != second.exercises[second.exercises.count - 2].name)
}

@Test func shortSessionsKeepStrengthOnly() throws {
    let result = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(availableMinutes: 20))
    let session = try #require(workout(result))
    #expect(session.exercises.allSatisfy { $0.priority < 4 })
}

@Test func mainLiftsKeepTwoMinutesOfRestInAThreeAxisSession() throws {
    let result = planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints())
    let session = try #require(workout(result))
    let mainLifts = session.exercises.filter { $0.priority == 1 }
    #expect(!mainLifts.isEmpty)
    #expect(mainLifts.allSatisfy { $0.restSeconds >= 120 && $0.sets == 4 })
}

@Test func strengthDayAfterALongBreakSaysLoadsAreLower() {
    let fiveWeeksAgo = utc.date(byAdding: .day, value: -35, to: tuesday)!
    let gym = planner.trainingDay(for: makeProfile(equipment: .gym), on: tuesday, constraints: DayConstraints(lastStrengthDay: fiveWeeksAgo))
    #expect(gym.notes.first?.hasPrefix("Reprise après 5 semaines") == true)
    let recent = planner.trainingDay(for: makeProfile(equipment: .gym), on: tuesday, constraints: DayConstraints(lastStrengthDay: utc.date(byAdding: .day, value: -3, to: tuesday)!))
    #expect(!recent.notes.contains { $0.hasPrefix("Reprise") })
}

@Test func fortyFiveMinutesAddIsolationBeforeTheCardio() throws {
    let session = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints())))
    let isolation = session.exercises.filter { $0.priority == 3 }
    #expect(isolation.map(\.name).contains("Élévations latérales haltères"))
    // Le cardio et la marche gardent leur place, après l'isolation.
    let lastIsolation = try #require(session.exercises.lastIndex { $0.priority == 3 })
    #expect(session.exercises[(lastIsolation + 1)...].allSatisfy { $0.priority == 4 })
    #expect(session.exercises.suffix(2).allSatisfy { $0.priority == 4 })
}

@Test func everyAccessoryHasAGuide() {
    for equipment in Equipment.allCases {
        for title in WorkoutCatalog.sessions(for: equipment).map(\.title) {
            for exercise in WorkoutCatalog.accessories(after: title, equipment: equipment) + [WorkoutCatalog.balance] {
                #expect(ExerciseGuide.guide(for: exercise.name) != nil, "\(exercise.name) sans fiche")
            }
        }
    }
}

@Test func cycleSessionsHaveNoExtraIsolation() {
    let week = CycleWeek(program: .crossfit, number: 2)
    #expect(planner.accessories(for: makeProfile(equipment: .gym), after: "Full body A", cycleWeek: week, on: monday).isEmpty)
}

@Test func seniorsLiftTenRepsWithBalanceAndPower() throws {
    var senior = makeProfile(equipment: .gym)
    senior.birthDate = day(1958, 1, 1)
    let result = planner.trainingDay(for: senior, on: monday, constraints: DayConstraints())
    let session = try #require(workout(result))
    let squat = try #require(session.exercises.first { $0.key == "Squat à la barre" })
    #expect(squat.volume == .reps(10))
    #expect(session.exercises.contains { $0.name == "Équilibre sur une jambe" })
    #expect(session.intensityCue.contains("Monte vite"))
    #expect(session.intensityCue.hasPrefix("Charge modérée"))
    // L'isolation ne passe pas avant les mouvements principaux.
    let mainKept = session.exercises.filter { $0.priority == 1 }.allSatisfy { $0.sets >= 3 }
    #expect(mainKept || !session.exercises.contains { $0.name == "Élévations latérales haltères" })
    #expect(result.notes.contains { $0.hasPrefix("À partir de 60 ans") })
}

@Test func highBMIGetsTenRepsWithoutBalance() throws {
    let result = planner.trainingDay(for: makeProfile(weightKg: 110, equipment: .gym), on: monday, constraints: DayConstraints())
    let session = try #require(workout(result))
    #expect(session.exercises.first { $0.key == "Développé couché" }?.volume == .reps(10))
    #expect(!session.exercises.contains { $0.name == "Équilibre sur une jambe" })
    #expect(result.notes.contains { $0.hasPrefix("Avec ton IMC") })
    // Profil de référence (IMC 27,8, 35 ans) : séries lourdes inchangées.
    let usual = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints())))
    #expect(usual.exercises.first { $0.key == "Squat à la barre" }?.volume == .reps(6))
}

@Test func shortAverageSleepIsMentionedWithoutChangingTheSession() {
    var constraints = DayConstraints(sleepHours: 7.5)
    let rested = planner.options(for: makeProfile(), on: monday, constraints: constraints)
    constraints.averageSleepHours = 6.25
    let short = planner.options(for: makeProfile(), on: monday, constraints: constraints)
    #expect(short.recommended == rested.recommended)
    #expect(short.reason.contains("Sommeil moyen de 6 h 15"))
    #expect(!rested.reason.contains("Sommeil moyen"))
}

import BodyPilotCore

/// Séances de base : deux full body alternés par équipement, conçues pour ~40 minutes.
enum WorkoutCatalog {
    static func sessions(for equipment: Equipment) -> [Workout] {
        switch equipment {
        case .bodyweight: [bodyweightA, bodyweightB]
        case .gym: [gymA, gymB]
        }
    }

    static let standardCue = "Garde 1 à 2 répétitions en réserve sur chaque série."

    static let bodyweightA = Workout(
        title: "Full body A",
        warmupMinutes: 5,
        cooldownMinutes: 3,
        exercises: [
            WorkoutExercise(name: "Squats", sets: 3, volume: .reps(15), restSeconds: 60, priority: 1, loadsKnee: true, kneeFriendlyAlternative: "Pont fessier une jambe"),
            WorkoutExercise(name: "Pompes (sur les genoux si besoin)", sets: 3, volume: .reps(10), restSeconds: 60, priority: 1),
            WorkoutExercise(name: "Fentes alternées", sets: 3, volume: .reps(12), restSeconds: 60, priority: 2, loadsKnee: true, kneeFriendlyAlternative: "Bird dog"),
            WorkoutExercise(name: "Pont fessier", sets: 3, volume: .reps(15), restSeconds: 45, priority: 2),
            WorkoutExercise(name: "Gainage planche", sets: 3, volume: .seconds(30), restSeconds: 45, priority: 2),
            WorkoutExercise(
                name: "Burpees", sets: 3, volume: .reps(8), restSeconds: 60, priority: 3,
                isHighImpact: true, lowImpactAlternative: "Squats avec extension des bras", loadsKnee: true, kneeFriendlyAlternative: "Boxe dans le vide"
            ),
        ],
        intensityCue: standardCue
    )

    static let bodyweightB = Workout(
        title: "Full body B",
        warmupMinutes: 5,
        cooldownMinutes: 3,
        exercises: [
            WorkoutExercise(name: "Squats sumo", sets: 3, volume: .reps(15), restSeconds: 60, priority: 1, loadsKnee: true, kneeFriendlyAlternative: "Pont fessier pieds surélevés"),
            WorkoutExercise(name: "Pompes inclinées", sets: 3, volume: .reps(12), restSeconds: 60, priority: 1),
            WorkoutExercise(name: "Superman au sol", sets: 3, volume: .reps(12), restSeconds: 45, priority: 2),
            WorkoutExercise(name: "Fentes arrière", sets: 3, volume: .reps(10), restSeconds: 60, priority: 2, loadsKnee: true, kneeFriendlyAlternative: "Gainage planche épaule touchée"),
            WorkoutExercise(name: "Gainage latéral", sets: 3, volume: .seconds(25), restSeconds: 45, priority: 3),
            WorkoutExercise(
                name: "Jumping jacks", sets: 3, volume: .seconds(40), restSeconds: 45, priority: 3,
                isHighImpact: true, lowImpactAlternative: "Montées de genoux marchées", loadsKnee: true, kneeFriendlyAlternative: "Boxe dans le vide"
            ),
        ],
        intensityCue: standardCue
    )

    static let gymA = Workout(
        title: "Full body A",
        warmupMinutes: 5,
        cooldownMinutes: 3,
        exercises: [
            WorkoutExercise(name: "Squat goblet", sets: 3, volume: .reps(10), restSeconds: 90, priority: 1, loadsKnee: true, kneeFriendlyAlternative: "Hip thrust"),
            WorkoutExercise(name: "Développé couché haltères", sets: 3, volume: .reps(10), restSeconds: 90, priority: 1),
            WorkoutExercise(name: "Tirage vertical", sets: 3, volume: .reps(12), restSeconds: 75, priority: 1),
            WorkoutExercise(name: "Soulevé de terre roumain", sets: 3, volume: .reps(10), restSeconds: 90, priority: 2),
            WorkoutExercise(name: "Gainage planche", sets: 2, volume: .seconds(40), restSeconds: 45, priority: 3),
        ],
        intensityCue: standardCue
    )

    static let gymB = Workout(
        title: "Full body B",
        warmupMinutes: 5,
        cooldownMinutes: 3,
        exercises: [
            WorkoutExercise(name: "Presse à cuisses", sets: 3, volume: .reps(12), restSeconds: 90, priority: 1, loadsKnee: true, kneeFriendlyAlternative: "Hip thrust"),
            WorkoutExercise(name: "Rowing haltère", sets: 3, volume: .reps(10), restSeconds: 75, priority: 1),
            WorkoutExercise(name: "Développé militaire haltères", sets: 3, volume: .reps(10), restSeconds: 75, priority: 2),
            WorkoutExercise(name: "Fentes marchées haltères", sets: 3, volume: .reps(10), restSeconds: 75, priority: 2, loadsKnee: true, kneeFriendlyAlternative: "Tirage horizontal à la poulie"),
            WorkoutExercise(
                name: "Corde à sauter", sets: 3, volume: .seconds(45), restSeconds: 45, priority: 3,
                isHighImpact: true, lowImpactAlternative: "Vélo d'appartement", loadsKnee: true, kneeFriendlyAlternative: "Rameur à allure douce"
            ),
        ],
        intensityCue: standardCue
    )
}

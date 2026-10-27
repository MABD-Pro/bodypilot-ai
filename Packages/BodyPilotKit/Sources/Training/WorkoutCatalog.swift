import BodyPilotCore

/// Séances sur trois axes : musculation lourde en full body, cardio varié, puis marche inclinée
/// ou escalier. Les blocs de force alternent (A / B) ; le cardio et la marche sont composés
/// par le planificateur selon le temps disponible.
enum WorkoutCatalog {
    static func sessions(for equipment: Equipment) -> [Workout] {
        switch equipment {
        case .bodyweight: [bodyweightA, bodyweightB]
        case .gym: [gymA, gymB]
        }
    }

    static let heavyCue = "Charge lourde : garde 1 à 2 répétitions en réserve et récupère complètement entre les séries."
    static let bodyweightCue = "Mouvements lents et contrôlés : garde 1 à 2 répétitions en réserve."

    // MARK: Force

    static let gymA = Workout(
        title: "Full body A",
        warmupMinutes: 6,
        cooldownMinutes: 2,
        exercises: [
            WorkoutExercise(name: "Squat à la barre", sets: 4, volume: .reps(6), restSeconds: 150, priority: 1, loadsKnee: true, kneeFriendlyAlternative: "Hip thrust", alternatives: ["Squat goblet lourd", "Presse à cuisses"]),
            WorkoutExercise(name: "Développé couché", sets: 4, volume: .reps(6), restSeconds: 150, priority: 1, alternatives: ["Développé couché haltères", "Développé à la machine"]),
            WorkoutExercise(name: "Tirage vertical lourd", sets: 4, volume: .reps(8), restSeconds: 120, priority: 2, alternatives: ["Tractions", "Tirage horizontal à la poulie"]),
            WorkoutExercise(name: "Soulevé de terre roumain", sets: 3, volume: .reps(8), restSeconds: 120, priority: 2, alternatives: ["Soulevé de terre roumain haltères", "Hip thrust"]),
        ],
        intensityCue: heavyCue
    )

    static let gymB = Workout(
        title: "Full body B",
        warmupMinutes: 6,
        cooldownMinutes: 2,
        exercises: [
            WorkoutExercise(name: "Soulevé de terre", sets: 4, volume: .reps(5), restSeconds: 180, priority: 1, alternatives: ["Soulevé de terre à la trap bar", "Soulevé de terre roumain"]),
            WorkoutExercise(name: "Développé militaire", sets: 4, volume: .reps(6), restSeconds: 150, priority: 1, alternatives: ["Développé militaire haltères", "Développé épaules à la machine"]),
            WorkoutExercise(name: "Rowing barre", sets: 4, volume: .reps(8), restSeconds: 120, priority: 2, alternatives: ["Rowing haltère", "Tirage horizontal à la poulie"]),
            WorkoutExercise(name: "Fentes bulgares haltères", sets: 3, volume: .reps(8), restSeconds: 90, priority: 2, loadsKnee: true, kneeFriendlyAlternative: "Hip thrust", alternatives: ["Fentes marchées haltères", "Step-ups haltères"]),
        ],
        intensityCue: heavyCue
    )

    static let bodyweightA = Workout(
        title: "Full body A",
        warmupMinutes: 5,
        cooldownMinutes: 2,
        exercises: [
            WorkoutExercise(name: "Squats bulgares", sets: 4, volume: .reps(10), restSeconds: 90, priority: 1, loadsKnee: true, kneeFriendlyAlternative: "Pont fessier une jambe", alternatives: ["Squats tempo lent", "Step-ups sur une chaise"]),
            WorkoutExercise(name: "Pompes", sets: 4, volume: .reps(12), restSeconds: 90, priority: 1, alternatives: ["Pompes déclinées", "Dips sur une chaise"]),
            WorkoutExercise(name: "Rowing inversé sous une table", sets: 4, volume: .reps(10), restSeconds: 90, priority: 2, alternatives: ["Rowing serviette à la porte", "Superman au sol"]),
            WorkoutExercise(name: "Gainage planche", sets: 3, volume: .seconds(40), restSeconds: 45, priority: 2, alternatives: ["Hollow hold", "Gainage latéral"]),
        ],
        intensityCue: bodyweightCue
    )

    static let bodyweightB = Workout(
        title: "Full body B",
        warmupMinutes: 5,
        cooldownMinutes: 2,
        exercises: [
            WorkoutExercise(name: "Squats tempo lent", sets: 4, volume: .reps(12), restSeconds: 90, priority: 1, loadsKnee: true, kneeFriendlyAlternative: "Pont fessier pieds surélevés", alternatives: ["Squats bulgares", "Step-ups sur une chaise"]),
            WorkoutExercise(name: "Pompes déclinées", sets: 4, volume: .reps(10), restSeconds: 90, priority: 1, alternatives: ["Pompes", "Dips sur une chaise"]),
            WorkoutExercise(name: "Hip thrust une jambe", sets: 4, volume: .reps(12), restSeconds: 60, priority: 2, alternatives: ["Pont fessier une jambe", "Good morning sans charge"]),
            WorkoutExercise(name: "Gainage latéral", sets: 3, volume: .seconds(30), restSeconds: 45, priority: 2, alternatives: ["Gainage planche", "Hollow hold"]),
        ],
        intensityCue: bodyweightCue
    )

    // MARK: Cardio varié

    /// Format de cardio : effort et récupération répétés, ou effort continu (`restSeconds` = 0).
    struct CardioFormat: Sendable {
        var name: String
        var workSeconds: Int
        var restSeconds: Int
        var isHighImpact = false
        var lowImpactAlternative: String?
        var loadsKnee = false
        var kneeFriendlyAlternative: String?
        var alternatives: [String] = []
    }

    static func cardio(for equipment: Equipment) -> [CardioFormat] {
        switch equipment {
        case .gym:
            [
                CardioFormat(name: "Rameur fractionné", workSeconds: 30, restSeconds: 30, alternatives: ["SkiErg fractionné", "Vélo fractionné"]),
                CardioFormat(name: "Vélo fractionné", workSeconds: 40, restSeconds: 20, alternatives: ["Assault bike", "Rameur fractionné"]),
                CardioFormat(
                    name: "Corde à sauter", workSeconds: 45, restSeconds: 30,
                    isHighImpact: true, lowImpactAlternative: "Vélo fractionné", loadsKnee: true, kneeFriendlyAlternative: "Rameur fractionné",
                    alternatives: ["Vélo fractionné", "Rameur fractionné"]
                ),
                CardioFormat(name: "Elliptique tempo", workSeconds: 0, restSeconds: 0, alternatives: ["Vélo tempo", "Rameur tempo"]),
            ]
        case .bodyweight:
            [
                CardioFormat(
                    name: "Burpees", workSeconds: 30, restSeconds: 30,
                    isHighImpact: true, lowImpactAlternative: "Squats avec extension des bras", loadsKnee: true, kneeFriendlyAlternative: "Boxe dans le vide",
                    alternatives: ["Squat thrusts", "Mountain climbers"]
                ),
                CardioFormat(name: "Mountain climbers", workSeconds: 30, restSeconds: 30, alternatives: ["Boxe dans le vide", "Jumping jacks"]),
                CardioFormat(
                    name: "Jumping jacks", workSeconds: 40, restSeconds: 20,
                    isHighImpact: true, lowImpactAlternative: "Pas chassés", loadsKnee: true, kneeFriendlyAlternative: "Boxe dans le vide",
                    alternatives: ["Pas chassés", "Montées de genoux"]
                ),
                CardioFormat(name: "Boxe dans le vide", workSeconds: 45, restSeconds: 15, alternatives: ["Mountain climbers", "Pas chassés"]),
            ]
        }
    }

    // MARK: Marche inclinée ou escalier

    /// La pente et les marches chargent le genou à chaque pas : avec une douleur, marche à plat ou vélo.

    struct InclineFormat: Sendable {
        var name: String
        var loadsKnee: Bool
        var kneeFriendlyAlternative: String?
        var alternatives: [String]
    }

    static func incline(for equipment: Equipment) -> [InclineFormat] {
        switch equipment {
        case .gym:
            [
                InclineFormat(name: "Marche inclinée (tapis 10 à 12 %, 5 km/h)", loadsKnee: true, kneeFriendlyAlternative: "Vélo à allure douce", alternatives: ["Escalier (stepper)", "Marche inclinée (tapis 8 %, 5,5 km/h)"]),
                InclineFormat(name: "Escalier (stepper)", loadsKnee: true, kneeFriendlyAlternative: "Vélo à allure douce", alternatives: ["Marche inclinée (tapis 10 à 12 %, 5 km/h)"]),
            ]
        case .bodyweight:
            [
                InclineFormat(name: "Marche en côte", loadsKnee: true, kneeFriendlyAlternative: "Marche à plat", alternatives: ["Montée d'escaliers", "Marche rapide"]),
                InclineFormat(name: "Montée d'escaliers", loadsKnee: true, kneeFriendlyAlternative: "Marche à plat", alternatives: ["Marche en côte"]),
            ]
        }
    }
}

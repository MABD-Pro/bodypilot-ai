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
            WorkoutExercise(name: "Tirage vertical lourd", sets: 4, volume: .reps(8), restSeconds: 120, priority: 2, alternatives: ["Tirage vertical prise serrée", "Tirage horizontal à la poulie", "Tractions"]),
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

    // MARK: Isolation

    /// Compléments d'isolation après la force : épaules (faisceau latéral), bras et mollets, que
    /// les polyarticulaires travaillent peu. 2 séries courtes, repos 45 s : environ 3 min chacun.
    /// Le volume par muscle compte pour la prise de muscle (Schoenfeld, Ogborn & Krieger, 2017).
    static func accessories(after title: String, equipment: Equipment) -> [WorkoutExercise] {
        let isB = title == gymB.title
        switch equipment {
        case .gym:
            return isB
                ? [
                    WorkoutExercise(name: "Extension triceps à la poulie", sets: 2, volume: .reps(12), restSeconds: 45, priority: 3, alternatives: ["Extension triceps haltère au-dessus de la tête", "Dips sur une chaise"]),
                    WorkoutExercise(name: "Mollets debout à la machine", sets: 2, volume: .reps(15), restSeconds: 45, priority: 3, alternatives: ["Mollets sur une marche"]),
                ]
                : [
                    WorkoutExercise(name: "Élévations latérales haltères", sets: 2, volume: .reps(15), restSeconds: 45, priority: 3, alternatives: ["Élévations latérales à la poulie"]),
                    WorkoutExercise(name: "Curl haltères", sets: 2, volume: .reps(12), restSeconds: 45, priority: 3, alternatives: ["Curl marteau", "Curl à la poulie"]),
                ]
        case .bodyweight:
            return isB
                ? [
                    WorkoutExercise(name: "Pompes diamant", sets: 2, volume: .reps(10), restSeconds: 45, priority: 3, alternatives: ["Dips sur une chaise"]),
                    WorkoutExercise(name: "Rowing serviette à la porte", sets: 2, volume: .reps(12), restSeconds: 45, priority: 3, alternatives: ["Superman au sol"]),
                ]
                : [
                    WorkoutExercise(name: "Pompes pike", sets: 2, volume: .reps(10), restSeconds: 45, priority: 3, alternatives: ["Pompes déclinées"]),
                    WorkoutExercise(name: "Mollets sur une marche", sets: 2, volume: .reps(20), restSeconds: 45, priority: 3),
                ]
        }
    }

    /// À partir de 65 ans : équilibre en premier complément (prévention des chutes,
    /// Sherrington et al., 2019).
    static let balance = WorkoutExercise(name: "Équilibre sur une jambe", sets: 2, volume: .seconds(30), restSeconds: 15, priority: 3)

    // MARK: Cycle CrossFit (salle) : rotation A / B / C

    static func cycleSessions(phase: Int) -> [Workout] {
        [gymA, gymB, gymC(phase: phase)]
    }

    static let gymCTitle = "Full body C"

    /// Force C : la haute fréquence du cycle, avec des variantes qui préparent le CrossFit
    /// (squat avant et push press en phase 2, thruster léger en phase 3).
    static func gymC(phase: Int) -> Workout {
        let core = WorkoutExercise(name: "Gainage planche", sets: 3, volume: .seconds(40), restSeconds: 45, priority: 2, alternatives: ["Hollow hold", "Gainage latéral"])
        let exercises: [WorkoutExercise] = phase <= 1
            ? [
                WorkoutExercise(name: "Squat goblet lourd", sets: 4, volume: .reps(8), restSeconds: 120, priority: 1, loadsKnee: true, kneeFriendlyAlternative: "Hip thrust", alternatives: ["Presse à cuisses"]),
                WorkoutExercise(name: "Développé couché haltères", sets: 4, volume: .reps(8), restSeconds: 120, priority: 1, alternatives: ["Développé à la machine"]),
                WorkoutExercise(name: "Rowing haltère", sets: 3, volume: .reps(10), restSeconds: 90, priority: 2, alternatives: ["Tirage horizontal à la poulie"]),
                core,
            ]
            : [
                WorkoutExercise(name: "Squat avant", sets: 4, volume: .reps(6), restSeconds: 150, priority: 1, loadsKnee: true, kneeFriendlyAlternative: "Hip thrust", alternatives: ["Squat goblet lourd"]),
                WorkoutExercise(name: "Push press", sets: 4, volume: .reps(6), restSeconds: 150, priority: 1, alternatives: ["Développé militaire"]),
                WorkoutExercise(name: "Tractions assistées", sets: 3, volume: .reps(6), restSeconds: 120, priority: 2, alternatives: ["Tirage vertical lourd", "Rowing aux anneaux"]),
            ] + (phase >= 3
                ? [WorkoutExercise(name: "Thruster léger", sets: 3, volume: .reps(8), restSeconds: 90, priority: 2, loadsKnee: true, kneeFriendlyAlternative: "Développé militaire haltères", alternatives: ["Wall ball"])]
                : [core])
        return Workout(title: gymCTitle, warmupMinutes: 6, cooldownMinutes: 2, exercises: exercises, intensityCue: heavyCue)
    }

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

    /// Jours de récupération musculaire : effort continu et modéré (zone 2), sans impact
    /// ni gainage intense, pour ne pas retarder la prochaine séance lourde.
    static func recoveryCardio(for equipment: Equipment) -> [CardioFormat] {
        switch equipment {
        case .gym:
            [
                CardioFormat(name: "Vélo à allure modérée", workSeconds: 0, restSeconds: 0, alternatives: ["Elliptique à allure modérée", "Rameur à allure modérée"]),
                CardioFormat(name: "Elliptique à allure modérée", workSeconds: 0, restSeconds: 0, alternatives: ["Vélo à allure modérée", "Rameur à allure modérée"]),
                CardioFormat(name: "Rameur à allure modérée", workSeconds: 0, restSeconds: 0, alternatives: ["Vélo à allure modérée", "Elliptique à allure modérée"]),
            ]
        case .bodyweight:
            [
                CardioFormat(name: "Marche rapide", workSeconds: 0, restSeconds: 0, alternatives: ["Boxe dans le vide, allure modérée", "Pas chassés"]),
                CardioFormat(name: "Boxe dans le vide, allure modérée", workSeconds: 0, restSeconds: 0, alternatives: ["Marche rapide", "Pas chassés"]),
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

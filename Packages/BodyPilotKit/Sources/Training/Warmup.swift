import BodyPilotCore
import Foundation

/// Une étape de l'échauffement ou du retour au calme.
public struct WarmupStep: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        /// Faire monter le pouls et la température.
        case pulse
        /// Mobilité dynamique ou étirement du retour au calme.
        case mobility
        /// Série de montée vers la charge de travail.
        case ramp
    }

    public var kind: Kind
    public var title: String
    /// « 3 min », « 10 rép. », « 8 par côté », « 5 × 40 kg ».
    public var detail: String

    public var id: String { title + detail }
}

/// Un échauffement ou un retour au calme, par blocs, avec ses consignes.
public struct WarmupPlan: Sendable, Equatable {
    public struct Block: Sendable, Equatable, Identifiable {
        public var title: String
        public var steps: [WarmupStep]
        public var id: String { title }
    }

    public var blocks: [Block]
    public var notes: [String]
}

/// Échauffement adapté à la séance, selon le protocole RAMP (Jeffreys 2007) : faire monter le
/// pouls, mobiliser les articulations des mouvements du jour, puis des séries de montée avant
/// le premier exercice lourd. L'échauffement améliore la performance (Fradkin et al. 2010) ;
/// les étirements statiques longs (plus de 60 s par muscle) juste avant réduisent la force
/// (Simic et al. 2013) : ils vont au retour au calme.
public enum WarmupPlanner {
    /// Familles de mouvements reconnues dans les noms d'exercices.
    enum Pattern: CaseIterable {
        case squat, hinge, push, pull

        func matches(_ name: String) -> Bool {
            let words: [String]
            switch self {
            case .squat: words = ["Squat", "Fente", "Thruster", "Wall ball", "wall balls"]
            case .hinge: words = ["Soulevé", "Hip thrust", "Kettlebell", "clean", "Rowing barre"]
            case .push: words = ["Développé", "Pompes", "Push press", "Thruster"]
            case .pull: words = ["Rowing", "Tirage", "Tractions", "rowings"]
            }
            return words.contains { name.contains($0) }
        }

        var mobility: [WarmupStep] {
            switch self {
            case .squat: [
                WarmupStep(kind: .mobility, title: "Squat au poids du corps, lent", detail: "10 rép."),
                WarmupStep(kind: .mobility, title: "Genou vers le mur, talon au sol", detail: "8 par côté"),
            ]
            case .hinge: [
                WarmupStep(kind: .mobility, title: "Charnière de hanche, mains sur les hanches", detail: "10 rép."),
                WarmupStep(kind: .mobility, title: "Pont fessier", detail: "10 rép."),
            ]
            case .push: [
                WarmupStep(kind: .mobility, title: "Cercles de bras, petits puis grands", detail: "10 par sens"),
                WarmupStep(kind: .mobility, title: "Pompes contre un mur", detail: "10 rép."),
            ]
            case .pull: [
                WarmupStep(kind: .mobility, title: "Rotation du buste à quatre pattes", detail: "8 par côté"),
                WarmupStep(kind: .mobility, title: "Y et T allongé sur le ventre", detail: "5 de chaque"),
            ]
            }
        }

        var stretch: WarmupStep {
            switch self {
            case .squat: WarmupStep(kind: .mobility, title: "Étirement des quadriceps, debout", detail: "30 s par côté")
            case .hinge: WarmupStep(kind: .mobility, title: "Étirement des ischio-jambiers", detail: "30 s par côté")
            case .push: WarmupStep(kind: .mobility, title: "Étirement des pectoraux contre un mur", detail: "30 s par côté")
            case .pull: WarmupStep(kind: .mobility, title: "Posture de l'enfant, bras loin devant", detail: "45 s")
            }
        }
    }

    /// Mouvements de la séance, dans l'ordre où ils apparaissent.
    static func patterns(of workout: Workout) -> [Pattern] {
        var found: [Pattern] = []
        for exercise in workout.exercises where exercise.priority < 4 {
            for pattern in Pattern.allCases where pattern.matches(exercise.name) && !found.contains(pattern) {
                found.append(pattern)
            }
        }
        return found
    }

    /// Mobilité des séances de cardio : hanches et chevilles.
    static let cardioMobility = [
        WarmupStep(kind: .mobility, title: "Balancés de jambe, avant-arrière", detail: "10 par côté"),
        WarmupStep(kind: .mobility, title: "Genou vers le mur, talon au sol", detail: "8 par côté"),
    ]

    /// - Parameters:
    ///   - atGym: vélo ou rameur à la salle, marche rapide sur place à la maison.
    ///   - firstLift: premier exercice lourd et sa première charge de travail, pour les séries de montée.
    public static func warmup(for workout: Workout, atGym: Bool, firstLift: (name: String, kg: Double)? = nil) -> WarmupPlan {
        let patterns = patterns(of: workout)
        let isCardio = patterns.isEmpty
        let pulseMinutes = isCardio ? max(3, workout.warmupMinutes - 2) : min(3, max(2, workout.warmupMinutes - 1))
        let cardio = workout.exercises.filter { $0.priority >= 4 }
        let runs = cardio.contains { $0.name.localizedCaseInsensitiveContains("course") || $0.name.contains(" km") }
        let pulse = WarmupStep(
            kind: .pulse,
            title: runs ? "Course très lente, puis un peu plus vite"
                : atGym ? "Vélo ou rameur, facile puis un peu plus vite" : "Marche rapide sur place, puis montées de genoux",
            detail: "\(pulseMinutes) min"
        )
        var blocks = [WarmupPlan.Block(title: "Faire monter le pouls", steps: [pulse])]

        var mobility: [WarmupStep] = []
        for step in (isCardio ? cardioMobility : patterns.flatMap(\.mobility)) where !mobility.contains(step) {
            mobility.append(step)
        }
        // Échauffement court : deux mouvements, pour tenir dans le temps prévu.
        blocks.append(WarmupPlan.Block(title: "Mobiliser", steps: Array(mobility.prefix(workout.warmupMinutes <= 4 ? 2 : 4))))

        var notes: [String] = []
        if isCardio {
            // Séance intense (fractionné, plusieurs efforts, allure de course) : quelques accélérations avant.
            let intense = cardio.contains { exercise in
                exercise.sets > 1 || ["fractionné", "allure", "soutenu"].contains { exercise.name.localizedCaseInsensitiveContains($0) }
            }
            if intense {
                blocks.append(WarmupPlan.Block(title: "Préparer l'effort", steps: [
                    WarmupStep(kind: .ramp, title: "Accélérations progressives, récupération facile entre deux", detail: "2 × 20 s"),
                ]))
            }
            notes.append("Le premier effort part à allure modérée : le pouls finit de monter pendant les premières minutes.")
        } else if workout.isStrengthTest {
            notes.append("Les séries de montée de chaque mouvement sont dans sa fiche : touche l'exercice.")
        } else {
            if let firstLift, firstLift.kg > 0 {
                blocks.append(WarmupPlan.Block(title: "Monter en charge : \(firstLift.name)", steps: ramp(for: firstLift.name, workingKg: firstLift.kg)))
                notes.append("Les séries de montée comptent dans le premier exercice, pas dans les minutes d'échauffement.")
            }
            notes.append("Avant chaque nouvel exercice : une série légère de 5 à 8 répétitions.")
            notes.append("Pas d'étirements longs maintenant : ils font perdre un peu de force. Garde-les pour le retour au calme.")
        }
        return WarmupPlan(blocks: blocks, notes: notes)
    }

    /// Séries de montée avant la première série de travail : environ 50, 70 et 85 % de sa charge,
    /// avec de moins en moins de répétitions pour ne pas fatiguer.
    public static func ramp(for exercise: String, workingKg: Double) -> [WarmupStep] {
        let barbell = ExerciseGuide.guide(for: exercise)?.barbell == true
        let step = barbell ? 2.5 : StrengthProgress.loadStep(for: workingKg)
        let floor = barbell ? StrengthCalibration.barbellKg : step
        var steps: [WarmupStep] = []
        if barbell && workingKg >= 40 {
            steps.append(WarmupStep(kind: .ramp, title: "Barre à vide", detail: "10 rép."))
        }
        var previous = barbell && workingKg >= 40 ? StrengthCalibration.barbellKg : 0
        for (reps, share) in [(5, 0.5), (3, 0.7), (1, 0.85)] {
            let kg = max(floor, (workingKg * share / step).rounded() * step)
            guard kg > previous, kg < workingKg else { continue }
            steps.append(WarmupStep(kind: .ramp, title: "\(kg.frenchCompact) kg", detail: "\(reps) rép."))
            previous = kg
        }
        return steps
    }

    /// Retour au calme : retour progressif au repos, puis étirements des muscles travaillés.
    /// Il aide à se sentir mieux ; il n'accélère pas vraiment la récupération (Van Hooren et Peake 2018).
    public static func cooldown(for workout: Workout, atGym: Bool) -> WarmupPlan {
        let patterns = patterns(of: workout)
        let easy = WarmupStep(
            kind: .pulse,
            title: atGym ? "Vélo ou marche très facile" : "Marche tranquille",
            detail: "\(max(1, min(5, workout.cooldownMinutes / 2))) min"
        )
        let stretches = patterns.isEmpty
            ? [
                WarmupStep(kind: .mobility, title: "Étirement des mollets contre un mur", detail: "30 s par côté"),
                WarmupStep(kind: .mobility, title: "Fente basse, bassin vers l'avant", detail: "30 s par côté"),
            ]
            : Array(patterns.map(\.stretch).prefix(3))
        return WarmupPlan(
            blocks: [
                WarmupPlan.Block(title: "Redescendre", steps: [easy]),
                WarmupPlan.Block(title: "Étirer, sans forcer", steps: stretches),
            ],
            notes: ["Respire lentement. Les étirements doivent tirer un peu, jamais faire mal."]
        )
    }
}

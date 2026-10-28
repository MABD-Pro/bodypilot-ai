import BodyPilotCore

/// Séance retouchée par l'utilisateur pour la journée : séries et volume changés, exercices
/// retirés ou ajoutés. Le coach propose, l'utilisateur garde la main.
public struct SessionEdits: Sendable, Equatable, Codable {
    /// Volume choisi pour un exercice (clé du catalogue) : séries, puis répétitions ou secondes.
    public struct Volume: Sendable, Equatable, Codable {
        public var sets: Int
        public var reps: Int?
        public var seconds: Int?

        public init(sets: Int, reps: Int? = nil, seconds: Int? = nil) {
            self.sets = sets
            self.reps = reps
            self.seconds = seconds
        }
    }

    public var removed: Set<String>
    public var volumes: [String: Volume]
    /// Exercices ajoutés, par nom, dans l'ordre d'ajout.
    public var added: [String]

    public init(removed: Set<String> = [], volumes: [String: Volume] = [:], added: [String] = []) {
        self.removed = removed
        self.volumes = volumes
        self.added = added
    }

    public var isEmpty: Bool { removed.isEmpty && volumes.isEmpty && added.isEmpty }

    /// Ateliers chronométrés : ajoutés en secondes plutôt qu'en répétitions.
    static let timed: Set<String> = [
        "SkiErg", "Poussée de traîneau", "Tirage de traîneau", "Burpees sautés en longueur",
        "Marche du fermier", "Fentes avec sac lesté", "Rameur",
    ]

    /// Exercice ajouté : 3 × 10 (3 × 1 min pour un atelier), à modifier ensuite.
    public static func addedExercise(_ name: String) -> WorkoutExercise {
        timed.contains(name)
            ? WorkoutExercise(name: name, sets: 3, volume: .seconds(60), restSeconds: 60, priority: 4)
            : WorkoutExercise(name: name, sets: 3, volume: .reps(10), restSeconds: 90, priority: 2)
    }

    /// Exercices proposés à l'ajout : ceux qui ont une fiche, triés par nom.
    public static var addableExercises: [String] {
        ExerciseGuide.catalog.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Les mêmes, rangés : la force d'abord, puis les ateliers chronométrés.
    public static var addableSections: [(title: String, exercises: [String])] {
        [
            ("Force", addableExercises.filter { !timed.contains($0) }),
            ("Ateliers Hyrox", addableExercises.filter { timed.contains($0) }),
        ]
    }

    public func apply(to workout: Workout) -> Workout {
        var result = workout
        let present = Set(workout.exercises.map(\.key))
        result.exercises = workout.exercises.filter { !removed.contains($0.key) }
            + added.filter { !present.contains($0) && !removed.contains($0) }.map(Self.addedExercise)
        result.exercises = result.exercises.map { exercise in
            guard let volume = volumes[exercise.key] else { return exercise }
            var edited = exercise
            // 5/3/1 : la vague fixe ses 3 séries, seules les séries « First Set Last » changent
            // (`sets` décrit alors la dernière série de la vague).
            if !edited.wave.isEmpty {
                edited.backoffSets = max(0, volume.sets - edited.wave.count)
                return edited
            }
            edited.sets = max(1, volume.sets)
            switch edited.volume {
            case .reps: if let reps = volume.reps { edited.volume = .reps(max(1, reps)) }
            case .seconds: if let seconds = volume.seconds { edited.volume = .seconds(max(10, seconds)) }
            }
            return edited
        }
        return result
    }

    public func apply(to day: TrainingDay) -> TrainingDay {
        guard !isEmpty, case .workout(let workout) = day.kind else { return day }
        let edited = apply(to: workout)
        // La séance n'est plus celle que le coach avait resserrée : la note ne vaut plus.
        let notes = day.notes.filter { !$0.hasPrefix(TrainingPlanner.fittedNotePrefix) }
        return TrainingDay(kind: .workout(edited), estimatedMinutes: edited.estimatedMinutes, notes: notes)
    }
}

import Foundation

/// Un exercice de la séance en cours, tel que le suivi (écran verrouillé) l'affiche.
public struct SessionStep: Codable, Hashable, Sendable {
    public var name: String
    /// Ce qui est prescrit, en court : « 3 × 10 », « 5-3-1+ · 5 × 5 ».
    public var detail: String
    public var sets: Int
    public var restSeconds: Int

    public init(name: String, detail: String, sets: Int, restSeconds: Int) {
        self.name = name
        self.detail = detail
        self.sets = max(1, sets)
        self.restSeconds = max(0, restSeconds)
    }
}

/// Où en est la séance : exercice, série, fin du repos. Une touche « Série faite » la fait avancer.
public struct SessionProgress: Codable, Hashable, Sendable {
    public var steps: [SessionStep]
    public var stepIndex: Int
    /// Série en cours, à partir de 1.
    public var setNumber: Int
    /// Fin du repos en cours ; `nil` : pas de repos.
    public var restEndsAt: Date?

    public init(steps: [SessionStep], stepIndex: Int = 0, setNumber: Int = 1, restEndsAt: Date? = nil) {
        self.steps = steps
        self.stepIndex = stepIndex
        self.setNumber = setNumber
        self.restEndsAt = restEndsAt
    }

    public var isFinished: Bool { stepIndex >= steps.count }
    public var current: SessionStep? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }
    public var next: SessionStep? { steps.indices.contains(stepIndex + 1) ? steps[stepIndex + 1] : nil }

    /// Série faite : série suivante après le repos de l'exercice, ou exercice suivant après le
    /// même repos. Rien après la dernière série de la séance.
    public func completingSet(at now: Date) -> SessionProgress {
        guard let current else { return self }
        var progress = self
        if setNumber < current.sets {
            progress.setNumber += 1
        } else {
            progress.stepIndex += 1
            progress.setNumber = 1
        }
        progress.restEndsAt = !progress.isFinished && current.restSeconds > 0
            ? now.addingTimeInterval(TimeInterval(current.restSeconds))
            : nil
        return progress
    }

    /// Exercice passé (machine prise, douleur) : le suivant tout de suite, sans repos.
    public func skippingExercise() -> SessionProgress {
        guard !isFinished else { return self }
        var progress = self
        progress.stepIndex += 1
        progress.setNumber = 1
        progress.restEndsAt = nil
        return progress
    }

    /// Part de la séance faite, en séries.
    public var fractionDone: Double {
        let total = steps.reduce(0) { $0 + $1.sets }
        guard total > 0 else { return 1 }
        let done = steps.prefix(stepIndex).reduce(0) { $0 + $1.sets } + (isFinished ? 0 : setNumber - 1)
        return min(1, Double(done) / Double(total))
    }
}

import Foundation

/// Zone d'une silhouette : plus fine que `MuscleGroup` (le dos devient dorsaux, trapèzes et
/// lombaires), pour montrer sur un dessin ce qu'un exercice travaille. Chaque zone appartient
/// à un groupe : la fatigue reste calculée par groupe.
public enum MuscleRegion: String, CaseIterable, Sendable, Codable {
    case chest, frontDeltoids, rearDeltoids, trapezius, lats, lowerBack
    case biceps, triceps, forearms
    case abs, obliques
    case glutes, quadriceps, adductors, hamstrings, calves

    public enum Side: Sendable { case front, back }

    /// Face ou dos : les avant-bras se voient des deux côtés.
    public var sides: [Side] {
        switch self {
        case .chest, .frontDeltoids, .biceps, .abs, .obliques, .quadriceps, .adductors: [.front]
        case .rearDeltoids, .trapezius, .lats, .lowerBack, .triceps, .glutes, .hamstrings, .calves: [.back]
        case .forearms: [.front, .back]
        }
    }

    public var group: MuscleGroup {
        switch self {
        case .chest: .chest
        case .frontDeltoids, .rearDeltoids: .shoulders
        case .trapezius, .lats, .lowerBack: .back
        case .biceps, .triceps, .forearms: .arms
        case .abs, .obliques: .core
        case .glutes, .adductors: .glutes
        case .quadriceps: .quadriceps
        case .hamstrings: .hamstrings
        case .calves: .calves
        }
    }

    public var label: String {
        switch self {
        case .chest: "Pectoraux"
        case .frontDeltoids: "Épaules (avant)"
        case .rearDeltoids: "Épaules (arrière)"
        case .trapezius: "Trapèzes"
        case .lats: "Grand dorsal"
        case .lowerBack: "Lombaires"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Avant-bras"
        case .abs: "Abdominaux"
        case .obliques: "Obliques"
        case .glutes: "Fessiers"
        case .quadriceps: "Quadriceps"
        case .adductors: "Adducteurs"
        case .hamstrings: "Ischio-jambiers"
        case .calves: "Mollets"
        }
    }

    /// Zones d'un intitulé de fiche (« Épaules, triceps, haut des pectoraux »), dans l'ordre.
    static func regions(in text: String) -> [MuscleRegion] {
        let word = text.lowercased()
        var found: [MuscleRegion] = []
        func add(_ regions: MuscleRegion...) {
            for region in regions where !found.contains(region) { found.append(region) }
        }
        if word.contains("jambes") { add(.quadriceps, .hamstrings, .glutes) }
        if word.contains("quadriceps") { add(.quadriceps) }
        if word.contains("ischio") { add(.hamstrings) }
        if word.contains("fessier") || word.contains("hanche") { add(.glutes) }
        if word.contains("adducteur") { add(.adductors) }
        if word.contains("mollet") || word.contains("cheville") { add(.calves) }
        if word.contains("pectora") { add(.chest) }
        if word.contains("grand dorsal") { add(.lats) }
        if word.contains("trapèze") || word.contains("haut du dos") || word.contains("dos (milieu)") { add(.trapezius) }
        if word.contains("lombaire") { add(.lowerBack) }
        // « Dos » seul : dorsaux et milieu du dos, sans les lombaires.
        if word.contains("dos"), !word.contains("dorsal"), !word.contains("haut du dos"), !word.contains("dos (milieu)") { add(.lats, .trapezius) }
        if word.contains("épaule") {
            if word.contains("avant") { add(.frontDeltoids) } else if word.contains("arrière") { add(.rearDeltoids) } else { add(.frontDeltoids, .rearDeltoids) }
        }
        if word.contains("biceps") { add(.biceps) }
        if word.contains("triceps") { add(.triceps) }
        if word.contains("avant-bras") { add(.forearms) }
        if word.contains("bras"), !word.contains("avant-bras") { add(.biceps, .triceps) }
        if word.contains("gainage") { add(.abs, .obliques) }
        if word.contains("abdo") { add(.abs) }
        return found
    }
}

/// Zones d'un exercice, principales puis secondaires, pour la silhouette d'une fiche.
public struct ExerciseRegions: Sendable, Equatable {
    public var primary: [MuscleRegion]
    public var secondary: [MuscleRegion]

    public init(primary: [MuscleRegion], secondary: [MuscleRegion]) {
        self.primary = primary
        self.secondary = secondary
    }

    public static func of(_ exercise: String) -> ExerciseRegions? {
        guard let guide = ExerciseGuide.guide(for: exercise) else { return nil }
        return parse(guide.muscles)
    }

    /// Lit un intitulé de fiche : le premier muscle cité travaille le plus, les suivants en appoint.
    public static func parse(_ muscles: String) -> ExerciseRegions? {
        let list = muscles.split(separator: ":").last.map(String.init) ?? muscles
        let parts = list.split(separator: ",").map { String($0) }
        guard let first = parts.first else { return nil }
        let primary = MuscleRegion.regions(in: first)
        let secondary = parts.dropFirst().flatMap { MuscleRegion.regions(in: $0) }
            .reduce(into: [MuscleRegion]()) { if !$0.contains($1) && !primary.contains($1) { $0.append($1) } }
        return primary.isEmpty && secondary.isEmpty ? nil : ExerciseRegions(primary: primary, secondary: secondary)
    }

    /// Zones principales d'une séance entière, puis ses secondaires, sans doublon.
    public static func of(_ workout: Workout) -> ExerciseRegions? {
        var primary: [MuscleRegion] = []
        var secondary: [MuscleRegion] = []
        for exercise in workout.exercises {
            guard let regions = of(exercise.name) else { continue }
            for region in regions.primary where !primary.contains(region) { primary.append(region) }
            for region in regions.secondary where !secondary.contains(region) { secondary.append(region) }
        }
        secondary.removeAll { primary.contains($0) }
        return primary.isEmpty && secondary.isEmpty ? nil : ExerciseRegions(primary: primary, secondary: secondary)
    }

    /// Le côté qui montre le plus de zones principales : la fiche l'affiche en premier.
    public var leadingSide: MuscleRegion.Side {
        let front = primary.filter { $0.sides.contains(.front) }.count
        let back = primary.filter { $0.sides.contains(.back) }.count
        return back > front ? .back : .front
    }
}

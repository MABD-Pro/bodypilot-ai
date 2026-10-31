import BodyPilotCore
import SwiftUI
import Training

/// Carte de fatigue par muscle : ce qui récupère encore après les séries notées ces derniers jours.
struct MuscleFatigueCard: View {
    let map: MuscleFatigueMap
    /// Muscles principaux de la séance du jour encore fatigués.
    let fatiguedTargets: [MuscleGroup]

    var body: some View {
        CoachCard(eyebrow: "Tes muscles", symbol: "figure.strengthtraining.traditional", tint: Theme.training) {
            Text(summary)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center, spacing: Theme.Spacing.l) {
                BodyMapPair(color: { Self.fill(map.state($0.group)) }, height: 150)
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(MuscleState.allCases.reversed(), id: \.self) { state in
                        legend(state)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            if !fatiguedTargets.isEmpty {
                CoachNote(text: targetsNote, tint: Self.color(.fatigued))
            }
            Text("D'après tes séries notées des trois derniers jours. Une séance lourde se récupère en 48 à 72\u{00A0}h.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summary: String {
        let fatigued = map.groups(.fatigued)
        let recovering = map.groups(.recovering)
        if !fatigued.isEmpty { return "Encore fatigués : \(Self.list(fatigued)). Laisse‑les souffler." }
        return "En récupération : \(Self.list(recovering)). Le reste est frais."
    }

    private var targetsNote: String {
        "Ta séance du jour sollicite encore : \(Self.list(fatiguedTargets)). Garde 2 à 3 répétitions en réserve ou remplace l'exercice."
    }

    private func legend(_ state: MuscleState) -> some View {
        let groups = map.groups(state)
        return HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Circle()
                .fill(Self.fill(state) ?? Color.primary.opacity(0.10))
                .frame(width: 9, height: 9)
                .offset(y: -1)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(groups.isEmpty ? "—" : Self.list(groups))
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accessibilityText: String {
        MuscleState.allCases.reversed().map { "\($0.label) : \(Self.list(map.groups($0)))" }.joined(separator: ". ")
    }

    /// Couleur sur la silhouette ; les muscles frais gardent la teinte du corps.
    static func fill(_ state: MuscleState) -> Color? {
        state == .fresh ? nil : color(state)
    }

    static func color(_ state: MuscleState) -> Color {
        switch state {
        case .fresh: Theme.progress
        case .recovering: Theme.carbs
        case .fatigued: Theme.nutrition
        }
    }

    static func stateLabel(_ state: MuscleState) -> String {
        switch state {
        case .fresh: "frais"
        case .recovering: "en récupération"
        case .fatigued: "fatigué"
        }
    }

    /// « quadriceps, fessiers et dos ».
    static func list(_ groups: [MuscleGroup]) -> String {
        let names = groups.map { $0.label.lowercased() }
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " et " + (names.last ?? "")
    }
}

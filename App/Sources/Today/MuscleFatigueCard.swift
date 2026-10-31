import BodyPilotCore
import SwiftUI
import Training

/// Carte de fatigue par muscle : ce qui récupère encore après les séries notées ces derniers jours.
struct MuscleFatigueCard: View {
    let map: MuscleFatigueMap
    /// Muscles principaux de la séance du jour encore fatigués.
    let fatiguedTargets: [MuscleGroup]

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s)]

    var body: some View {
        CoachCard(eyebrow: "Tes muscles", symbol: "figure.strengthtraining.traditional", tint: Theme.training) {
            Text(summary)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    tile(group)
                }
            }
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
        if !fatigued.isEmpty { return "Encore fatigués : \(Self.list(fatigued)). Laisse-les souffler." }
        return "En récupération : \(Self.list(recovering)). Le reste est frais."
    }

    private var targetsNote: String {
        "Ta séance du jour sollicite encore : \(Self.list(fatiguedTargets)). Garde 2 à 3 répétitions en réserve ou remplace l'exercice."
    }

    private func tile(_ group: MuscleGroup) -> some View {
        let state = map.state(group)
        return VStack(alignment: .leading, spacing: 6) {
            Text(group.label)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 3) {
                ForEach(MuscleState.allCases, id: \.self) { level in
                    Capsule()
                        .fill(level <= state ? Self.color(state) : Color.primary.opacity(0.1))
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.color(state).opacity(state == .fresh ? 0.06 : 0.16), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(group.label) : \(Self.stateLabel(state))")
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

import Coach
import SwiftUI

/// « Je n'ai que 20 minutes », « Je suis fatigué »… : le plan s'adapte en une touche.
struct AdjustmentBar: View {
    let active: Set<QuickAdjustment>
    let toggle: (QuickAdjustment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Aujourd'hui, plutôt…")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: Theme.Spacing.s) {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(QuickAdjustment.allCases, id: \.self) { adjustment in
                            chip(adjustment)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private func chip(_ adjustment: QuickAdjustment) -> some View {
        let isOn = active.contains(adjustment)
        return Button {
            toggle(adjustment)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark" : adjustment.symbol)
                    .contentTransition(.symbolEffect(.replace))
                Text(adjustment.phrase)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(adjustment.tint).interactive() : .regular.interactive(), in: .capsule)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

extension QuickAdjustment {
    var symbol: String {
        switch self {
        case .shortOnTime: "timer"
        case .tired: "battery.25percent"
        case .missedWorkout: "arrow.uturn.backward"
        case .eatingOut: "fork.knife"
        case .notHungry: "leaf"
        case .kneePain: "bandage"
        case .traveling: "suitcase.rolling"
        }
    }

    var tint: Color {
        switch self {
        case .shortOnTime, .traveling: Theme.training
        case .tired: Theme.fat
        case .missedWorkout, .kneePain: Theme.protein
        case .eatingOut, .notHungry: Theme.nutrition
        }
    }

    /// Version courte pour la confirmation (« resto », « genou »).
    var shortLabel: String {
        switch self {
        case .shortOnTime: "peu de temps"
        case .tired: "fatigue"
        case .missedWorkout: "séance ratée"
        case .eatingOut: "restaurant"
        case .notHungry: "pas faim"
        case .kneePain: "genou"
        case .traveling: "déplacement"
        }
    }
}

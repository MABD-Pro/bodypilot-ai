import BodyPilotCore
import Coach
import SwiftUI

/// Ce que l'agenda du jour change : le coach propose, une touche applique.
struct AgendaCard: View {
    let advice: AgendaAdvice
    /// Ajustements déjà actifs aujourd'hui : leur proposition disparaît.
    let active: Set<QuickAdjustment>
    let apply: (QuickAdjustment) -> Void
    let dismiss: () -> Void

    /// Propositions encore à faire.
    static func pending(_ advice: AgendaAdvice, active: Set<QuickAdjustment>) -> [QuickAdjustment] {
        advice.suggestions.filter { !active.contains($0) }
    }

    var body: some View {
        CoachCard(eyebrow: "Ton agenda", symbol: "calendar", tint: Theme.training) {
            if let slot = advice.freeSlot {
                Label("Créneau libre pour ta séance : \(Self.time(slot.start))\u{00A0}– \(Self.time(slot.end))", systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Self.pending(advice, active: active), id: \.self) { adjustment in
                row(adjustment)
            }
            Button("Pas aujourd'hui", action: dismiss)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ adjustment: QuickAdjustment) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title(adjustment))
                    .font(.subheadline.weight(.semibold))
                Text(reason(adjustment))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Spacing.s)
            Button("Appliquer") { apply(adjustment) }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.glassProminent)
                .tint(Theme.training)
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    private func title(_ adjustment: QuickAdjustment) -> String {
        switch adjustment {
        case .shortOnTime: "Séance de \(advice.shortOnTimeMinutes ?? QuickAdjustment.shortOnTimeMinutes) min"
        case .eatingOut: advice.eatingOut?.slot == .lunch ? "Déjeuner au restaurant" : "Dîner au restaurant"
        case .traveling: "Journée en déplacement"
        default: adjustment.phrase
        }
    }

    private func reason(_ adjustment: QuickAdjustment) -> String {
        switch adjustment {
        case .shortOnTime:
            "Ta plus longue pause fait \(advice.shortOnTimeMinutes ?? 0) min : la séance tient dedans."
        case .eatingOut:
            "« \(advice.eatingOut?.event ?? "") » : ce repas devient « Au restaurant », les autres s'ajustent."
        case .traveling:
            "« \(advice.travelEvent ?? "") » : séance courte sans matériel et repères simples pour manger."
        default: ""
        }
    }

    /// « 12 h », « 12 h 15 ».
    static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return minute == 0 ? "\(hour)\u{00A0}h" : "\(hour)\u{00A0}h\u{00A0}\(String(format: "%02d", minute))"
    }
}

/// Une fois : proposer la lecture de l'agenda, sans la demander à l'inscription.
struct AgendaInviteCard: View {
    let enable: () -> Void
    let dismiss: () -> Void

    var body: some View {
        CoachCard(eyebrow: "Ton agenda", symbol: "calendar.badge.plus", tint: Theme.training) {
            Text("Moins de choses à me dire")
                .font(.title3.weight(.semibold))
            Text("Je peux lire tes événements du jour : un restaurant, un déplacement ou une journée trop pleine, et je te propose l'ajustement. Tu choisis toujours. Rien ne quitte ton iPhone.")
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.s) {
                Button(action: enable) {
                    Text("Lire mon agenda")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.training)
                Button(action: dismiss) {
                    Text("Non merci")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
            }
        }
    }
}

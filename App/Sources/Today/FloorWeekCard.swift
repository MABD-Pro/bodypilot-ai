import BodyPilotCore
import ProgressInsights
import SwiftUI

/// Retour après quelques jours sans rien noter : une semaine plancher plutôt qu'un rattrapage.
struct ComebackCard: View {
    let comeback: Comeback
    let startFloorWeek: () -> Void
    let dismiss: () -> Void

    var body: some View {
        CoachCard(eyebrow: "On repart", symbol: "arrow.uturn.forward.circle.fill", tint: Theme.progress) {
            Text(comeback.title)
                .font(.title3.weight(.semibold))
            Text(comeback.message)
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.s) {
                Button(action: startFloorWeek) {
                    Text("Semaine plancher")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.progress)
                Button(action: dismiss) {
                    Text("Plus tard")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
            }
        }
    }
}

/// La semaine plancher en cours : trois cases, ce qui est tenu se coche.
struct FloorWeekCard: View {
    let progress: FloorWeekProgress
    let stop: () -> Void

    var body: some View {
        CoachCard(eyebrow: "Semaine plancher · jour \(progress.day) sur \(FloorWeek.days)", symbol: "square.stack.3d.down.forward.fill", tint: Theme.progress) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                row(
                    done: progress.strengthSessions >= FloorWeek.strengthSessions,
                    title: "Force : \(min(progress.strengthSessions, FloorWeek.strengthSessions)) séance\(progress.strengthSessions > 1 ? "s" : "") sur \(FloorWeek.strengthSessions)",
                    detail: "Séances de \(FloorWeek.sessionMinutes)\u{00A0}min cette semaine."
                )
                row(
                    done: progress.proteinDays >= FloorWeek.proteinDays,
                    title: "Protéines : \(min(progress.proteinDays, FloorWeek.proteinDays)) jour\(progress.proteinDays > 1 ? "s" : "") sur \(FloorWeek.proteinDays)",
                    detail: "Atteintes quand tes repas notés les couvrent."
                )
                row(done: progress.weighedIn, title: progress.weighedIn ? "Pesée faite" : "Une pesée", detail: nil)
            }
            Text(progress.message)
                .font(.subheadline.weight(progress.isHeld ? .semibold : .regular))
                .foregroundStyle(progress.isHeld ? Theme.progress : Color.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Button("Reprendre le plan complet", action: stop)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func row(done: Bool, title: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Theme.progress : .secondary)
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}

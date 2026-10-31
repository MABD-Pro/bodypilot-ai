import ProgressInsights
import SwiftUI

/// Garde-fou alimentaire : un message calme, une pause du déficit, des adresses d'aide.
/// Aucun chiffre ni détail du signal, pour ne pas faire honte ni donner d'objectif.
struct EatingCareCard: View {
    let signals: Set<EatingCareSignal>
    let pause: () -> Void
    let showHelp: () -> Void
    let dismiss: () -> Void

    var body: some View {
        CoachCard(eyebrow: "Garde-fou", symbol: "heart.circle.fill", tint: Theme.protein) {
            Text(EatingCareText.title)
                .font(.title3.weight(.semibold))
            ForEach(EatingCareText.paragraphs(for: signals), id: \.self) { paragraph in
                Text(paragraph)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: Theme.Spacing.s) {
                if signals.contains(.purging) {
                    helpButton.buttonStyle(.glassProminent).tint(Theme.protein)
                    pauseButton.buttonStyle(.glass)
                } else {
                    pauseButton.buttonStyle(.glassProminent).tint(Theme.protein)
                    helpButton.buttonStyle(.glass)
                }
            }
            Button("Ça va, merci", action: dismiss)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var pauseButton: some View {
        Button(action: pause) {
            Text("Mettre le déficit en pause")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var helpButton: some View {
        Button(action: showHelp) {
            Text("Trouver de l'aide")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

/// « Trouver de l'aide » : le médecin, la ligne d'écoute de la FFAB, les urgences.
struct EatingCareHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ton médecin traitant").font(.headline)
                            Text("Le premier interlocuteur. Il peut t'orienter vers une équipe spécialisée.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "stethoscope")
                    }
                }
                Section {
                    // Numéro vérifié le 2026-10-31 sur ffab.fr et reseautca-idf.org.
                    Link(destination: URL(string: "tel:0969325900")!) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Anorexie Boulimie Info Écoute").font(.headline)
                                Text("09\u{00A0}69\u{00A0}325\u{00A0}900")
                                    .font(.title3.weight(.semibold))
                                    .monospacedDigit()
                                Text("Lundi, mardi, jeudi et vendredi, de 16\u{00A0}h à 18\u{00A0}h, hors jours fériés. Appel non surtaxé.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "phone.fill")
                        }
                    }
                } footer: {
                    Text("Ligne de la Fédération française Anorexie Boulimie : psychologues, médecins et associations de familles selon le jour.")
                }
                Section {
                    Link(destination: URL(string: "tel:15")!) {
                        Label("Urgence : 15 ou 112", systemImage: "cross.case.fill")
                    }
                }
            }
            .navigationTitle("Trouver de l'aide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

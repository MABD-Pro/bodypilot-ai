import SwiftUI

/// Premier lancement : « Aider à améliorer BodyPilot ». Refuser est aussi simple qu'accepter
/// (CNIL), et le choix se change ensuite dans Mon profil > Confidentialité.
struct ConsentView: View {
    let answer: (TelemetryConsent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Spacer(minLength: 0)

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.progress.gradient)
                .padding(.bottom, Theme.Spacing.s)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Aider à améliorer BodyPilot")
                    .font(.display(32))
                Text("Tu choisis. L'app marche pareil dans les deux cas.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                ConsentPoint(symbol: "ladybug", text: "Si l'app plante, un rapport technique part chez Firebase Crashlytics (Google) pour corriger le problème.")
                ConsentPoint(symbol: "chart.bar", text: "Des statistiques d'usage anonymes disent quelles fonctions servent, sans aucun contenu.")
                ConsentPoint(symbol: "heart.slash", text: "Jamais tes données de santé, ton poids, tes repas, tes séances ni ce que tu écris. Aucune publicité.")
            }
            .padding(Theme.Spacing.l)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.inner + 4))

            Spacer(minLength: 0)

            // Deux boutons de même taille et de même style : aucun choix n'est mis en avant.
            HStack(spacing: Theme.Spacing.m) {
                choice("Refuser", .denied)
                choice("Accepter", .granted)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xxl)
        .background { AppBackground() }
    }

    private func choice(_ title: String, _ value: TelemetryConsent) -> some View {
        Button { answer(value) } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s)
        }
        .buttonStyle(.glass)
    }
}

private struct ConsentPoint: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.progress)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Mon profil > Confidentialité : changer d'avis à tout moment.
struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shares = Telemetry.consent == .granted

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Rapports de plantage et statistiques d'usage", isOn: $shares)
                } footer: {
                    Text("Envoyés à Firebase (Google) pour corriger les plantages et savoir quelles fonctions servent. Jamais tes données de santé, ton poids, tes repas, tes séances ni ce que tu écris. Aucune publicité. Couper efface les rapports pas encore envoyés.")
                }
                if !Telemetry.isAvailable {
                    Section {
                        Text("Cette version de l'app n'envoie rien, quel que soit ce réglage.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Confidentialité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .onChange(of: shares) { _, value in
                Telemetry.setConsent(value ? .granted : .denied)
            }
        }
    }
}

#Preview {
    ConsentView { _ in }
}

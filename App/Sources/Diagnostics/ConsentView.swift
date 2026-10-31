import ProgressInsights
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
    @AppStorage(CoachNotifications.enabledKey) private var reminders = true
    @AppStorage(CoachNotifications.sessionKey) private var sessionReminder = false
    @State private var remindersDenied = false
    @State private var hasGym = GymArrival.savedCoordinate != nil
    @State private var isSavingGym = false
    @State private var gymFailure: GymArrival.Failure?

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
                        Text("Cette version de l'app n'envoie aucun rapport ni statistique, quel que soit ce réglage.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle("Rappels du coach", isOn: $reminders)
                } footer: {
                    if reminders, remindersDenied, let settings = URL(string: UIApplication.openNotificationSettingsURLString) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Les notifications de BodyPilot sont coupées dans Réglages.")
                            Link("Ouvrir Réglages", destination: settings)
                        }
                    } else {
                        Text("Rares et sans reproche : un message après quelques jours sans nouvelles, et un pendant la semaine plancher s'il manque une séance.")
                    }
                }
                if reminders {
                    Section {
                        Toggle("Rappel avant ma séance", isOn: $sessionReminder)
                    } footer: {
                        if let minute = CoachNotifications.usualSessionMinute {
                            Text("Tu t'entraînes d'habitude vers \(TrainingRhythm.label(minute: minute)) : un message \(CoachReminders.sessionLeadMinutes)\u{00A0}min avant, seulement si ta séance du jour n'est pas faite.")
                        } else {
                            Text("Je n'ai pas encore repéré ton heure habituelle : il faut quelques séances enregistrées dans Santé (Watch ou autre app) à des heures proches. Un message \(CoachReminders.sessionLeadMinutes)\u{00A0}min avant, seulement si ta séance du jour n'est pas faite.")
                        }
                    }
                }
                gymSection
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
            .onChange(of: sessionReminder) { _, value in
                guard value else { return }
                Task { remindersDenied = !(await CoachNotifications.requestAuthorization()) }
            }
            .onChange(of: reminders) { _, value in
                guard value else { return }
                Task { remindersDenied = !(await CoachNotifications.requestAuthorization()) }
            }
            .task {
                remindersDenied = await CoachNotifications.isDenied()
                // Autorisation « Une fois » expirée ou retirée : le rappel ne partira plus, autant le dire.
                guard hasGym, !LaunchOptions.demoGym else { return }
                let scheduled = await GymArrival.isScheduled()
                if !GymArrival.canDetectArrival || !scheduled { gymFailure = .notScheduled }
            }
        }
    }

    /// « Ma salle » : rappel à l'arrivée, enregistré une fois sur place.
    private var gymSection: some View {
        Section {
            if hasGym {
                Label("Rappel en arrivant à ma salle", systemImage: "mappin.and.ellipse")
                Button("Remplacer par ma position actuelle", action: saveGym)
                    .disabled(isSavingGym)
                Button("Oublier ma salle", role: .destructive) {
                    GymArrival.forget()
                    withAnimation(Theme.springy) { hasGym = false }
                }
            } else {
                Button(action: saveGym) {
                    HStack {
                        Label("Je suis à ma salle : enregistrer ce lieu", systemImage: "mappin.and.ellipse")
                        if isSavingGym {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isSavingGym)
            }
        } header: {
            Text("Ma salle")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                switch gymFailure {
                case .locationDenied?:
                    Text("La localisation de BodyPilot est coupée dans Réglages.")
                    if let settings = URL(string: UIApplication.openSettingsURLString) {
                        Link("Ouvrir Réglages", destination: settings)
                    }
                case .notificationsDenied?:
                    Text("Les notifications de BodyPilot sont coupées dans Réglages.")
                    if let settings = URL(string: UIApplication.openNotificationSettingsURLString) {
                        Link("Ouvrir Réglages", destination: settings)
                    }
                case .notScheduled?:
                    if GymArrival.canDetectArrival {
                        Text("iOS n'a pas accepté le rappel d'arrivée. Réessaie sur place, ou vérifie la position et les notifications de BodyPilot dans Réglages.")
                    } else {
                        Text("iOS ne peut plus te prévenir à l'arrivée : la position doit rester autorisée « Lorsque l'app est active » (pas « Une fois »). Touche « Remplacer par ma position actuelle » sur place pour réactiver le rappel.")
                    }
                case .locationUnavailable?:
                    Text("Position introuvable pour l'instant. Réessaie près d'une fenêtre ou à l'entrée de la salle.")
                case nil:
                    Text(hasGym
                         ? "Un message quand tu arrives à ta salle, pour ouvrir ta séance du jour. C'est iOS qui repère l'arrivée : BodyPilot ne suit pas ta position et le lieu reste sur ton iPhone."
                         : "À faire une fois, sur place : ensuite, un message quand tu arrives à ta salle pour ouvrir ta séance du jour. Autorise la position « Lorsque l'app est active » : le lieu reste sur ton iPhone et BodyPilot ne suit pas ta position.")
                }
            }
        }
    }

    private func saveGym() {
        isSavingGym = true
        gymFailure = nil
        Task {
            let result = await GymArrival.saveCurrentLocation()
            withAnimation(Theme.springy) {
                isSavingGym = false
                switch result {
                case .success: hasGym = true
                case .failure(let failure): gymFailure = failure
                }
            }
        }
    }
}

#Preview {
    ConsentView { _ in }
}

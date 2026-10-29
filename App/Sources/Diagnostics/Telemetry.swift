import BodyPilotCore
import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import Foundation

/// Réponse de l'utilisateur à « Aider à améliorer BodyPilot ».
enum TelemetryConsent: String {
    case undetermined, granted, denied
}

/// Rapports de plantage (Crashlytics) et statistiques d'usage (Analytics).
///
/// Rien ne part sans accord : la collecte est coupée dans l'Info.plist et ne s'allume qu'après
/// « Accepter ». Sans `GoogleService-Info.plist` dans l'app (fichier jamais versionné), Firebase
/// n'est pas démarré et tout ici ne fait rien. Les données de démo n'envoient rien non plus.
@MainActor
enum Telemetry {
    private static let consentKey = "telemetryConsent"

    /// Firebase est configuré pour cette installation.
    private(set) static var isAvailable = false

    static var consent: TelemetryConsent {
        TelemetryConsent(rawValue: UserDefaults.standard.string(forKey: consentKey) ?? "") ?? .undetermined
    }

    /// La question n'a pas encore été posée (jamais en démo, sauf `-demoConsent YES`).
    static var needsConsent: Bool {
        if LaunchOptions.demoConsent { return true }
        return isAvailable && consent == .undetermined
    }

    static func start() {
        guard !LaunchOptions.isDemo else { return }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            AppLog.telemetry.info("GoogleService-Info.plist absent : Firebase reste éteint")
            return
        }
        FirebaseApp.configure()
        isAvailable = true
        apply(consent)
    }

    static func setConsent(_ value: TelemetryConsent) {
        UserDefaults.standard.set(value.rawValue, forKey: consentKey)
        AppLog.telemetry.notice("Consentement : \(value.rawValue, privacy: .public)")
        apply(value)
    }

    static func record(_ event: UsageEvent) {
        guard isAvailable, consent == .granted else { return }
        Analytics.logEvent(event.name, parameters: nil)
    }

    /// Erreur sans plantage, réduite à son domaine et son code : jamais de message ni de valeur.
    static func recordNonFatal(_ error: any Error) {
        guard isAvailable, consent == .granted else { return }
        let nsError = error as NSError
        Crashlytics.crashlytics().record(error: NSError(domain: nsError.domain, code: nsError.code))
    }

    private static func apply(_ consent: TelemetryConsent) {
        guard isAvailable else { return }
        let granted = consent == .granted
        // Pas de publicité, quel que soit le choix : seuls les rapports d'usage peuvent être autorisés.
        Analytics.setConsent([
            .analyticsStorage: granted ? .granted : .denied,
            .adStorage: .denied,
            .adUserData: .denied,
            .adPersonalization: .denied,
        ])
        Analytics.setAnalyticsCollectionEnabled(granted)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(granted)
        if consent == .denied {
            Analytics.resetAnalyticsData()
            Crashlytics.crashlytics().deleteUnsentReports()
        }
    }
}

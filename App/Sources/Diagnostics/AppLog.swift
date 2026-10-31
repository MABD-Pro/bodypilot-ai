import OSLog

/// Journaux de l'app, lisibles dans Console.app (filtre « com.mabdpro.bodypilot ») ou avec
/// `log stream --predicate 'subsystem == "com.mabdpro.bodypilot"'`. Ils restent sur l'appareil
/// et ne partent ni vers Crashlytics ni vers Analytics : une valeur personnelle s'écrit
/// toujours en `privacy: .private`.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.mabdpro.bodypilot"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let health = Logger(subsystem: subsystem, category: "health")
    static let backup = Logger(subsystem: subsystem, category: "backup")
    static let telemetry = Logger(subsystem: subsystem, category: "telemetry")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let products = Logger(subsystem: subsystem, category: "products")
}

import AIRouter
import Foundation

/// Registre des appels aux modèles, gardé sur l'iPhone entre deux lancements :
/// appels, niveau, latence et échecs par fonctionnalité (rien n'est envoyé ailleurs).
enum AIUsageStore {
    static let shared = AIUsageLedger(records: load(), persist: save)

    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "ai-usage.json")
    }

    private static func load() -> [AIUsageRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([AIUsageRecord].self, from: data)) ?? []
    }

    @Sendable private static func save(_ records: [AIUsageRecord]) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(records).write(to: url, options: .atomic)
    }
}

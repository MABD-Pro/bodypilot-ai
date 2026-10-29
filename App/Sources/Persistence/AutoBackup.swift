import Foundation
import SwiftData

/// Sauvegarde automatique : une copie par jour dans un dossier que l'utilisateur choisit une fois.
/// Ce choix vaut autorisation : l'app garde un signet vers le dossier pour y revenir sans
/// redemander, et n'écrit nulle part ailleurs. Les plus anciennes copies sont supprimées.
@MainActor
enum AutoBackup {
    /// Copies gardées dans le dossier : une semaine de retour en arrière.
    static let keptCopies = 7
    /// Moins de 24 h : la copie d'un soir n'empêche pas celle du lendemain matin.
    static let interval: TimeInterval = 20 * 3600

    private static var defaults: UserDefaults { .standard }
    private static let bookmarkKey = "autoBackup.bookmark"
    private static let lastKey = "autoBackup.lastAt"
    private static let errorKey = "autoBackup.error"

    static var isOn: Bool { defaults.data(forKey: bookmarkKey) != nil }
    static var lastBackup: Date? { defaults.object(forKey: lastKey) as? Date }
    static var lastError: String? { defaults.string(forKey: errorKey) }

    /// Nom du dossier choisi, pour l'afficher.
    static var folderName: String? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        return (try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale))?.lastPathComponent
    }

    /// Retient le dossier choisi et y écrit aussitôt une première copie.
    static func enable(folder: URL, context: ModelContext, now: Date = .now) throws {
        let granted = folder.startAccessingSecurityScopedResource()
        defer { if granted { folder.stopAccessingSecurityScopedResource() } }
        let bookmark = try folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        try write(to: folder, context: context, now: now)
        defaults.set(bookmark, forKey: bookmarkKey)
    }

    static func disable() {
        for key in [bookmarkKey, lastKey, errorKey] { defaults.removeObject(forKey: key) }
    }

    /// Au passage en arrière-plan : une copie si la dernière date d'au moins 20 h.
    /// Un échec est retenu pour être affiché dans « Mes données », sans rien bloquer.
    static func runIfDue(context: ModelContext, now: Date = .now) {
        guard let data = defaults.data(forKey: bookmarkKey) else { return }
        if let lastBackup, now.timeIntervalSince(lastBackup) < interval { return }
        do {
            var stale = false
            let folder: URL
            do {
                folder = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
            } catch {
                throw AutoBackupError.folderMissing
            }
            let granted = folder.startAccessingSecurityScopedResource()
            defer { if granted { folder.stopAccessingSecurityScopedResource() } }
            if stale, let fresh = try? folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
                defaults.set(fresh, forKey: bookmarkKey)
            }
            try write(to: folder, context: context, now: now)
        } catch {
            AppLog.backup.error("Sauvegarde automatique impossible : \(error.localizedDescription, privacy: .public)")
            defaults.set(error.localizedDescription, forKey: errorKey)
        }
    }

    private static func write(to folder: URL, context: ModelContext, now: Date) throws {
        let archive = try Backup.archive(from: context)
        // Rien à garder avant l'inscription : pas de fichier vide qui chasserait une vraie copie.
        guard !archive.isEmpty else { return }
        let data = try Backup.encode(archive)
        // Le dossier peut appartenir à un autre fournisseur (iCloud Drive, disque externe) :
        // l'écriture passe par le coordinateur de fichiers.
        try coordinate(folder.appending(path: Backup.fileName(on: now)), options: .forReplacing) { target in
            try data.write(to: target, options: .atomic)
        }
        try prune(folder)
        defaults.set(now, forKey: lastKey)
        defaults.removeObject(forKey: errorKey)
    }

    /// Supprime les copies au-delà des 7 plus récentes. Seuls les fichiers « BodyPilot-AAAA-MM-JJ.json »
    /// sont concernés : le reste du dossier n'est jamais touché.
    private static func prune(_ folder: URL) throws {
        let copies = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { isCopy($0.lastPathComponent) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in copies.dropFirst(keptCopies) {
            try coordinate(old, options: .forDeleting) { try FileManager.default.removeItem(at: $0) }
        }
    }

    /// « BodyPilot-2026-10-28.json » : le nom trié suit l'ordre des dates.
    static func isCopy(_ name: String) -> Bool {
        name.wholeMatch(of: #/BodyPilot-\d{4}-\d{2}-\d{2}\.json/#) != nil
    }

    private static func coordinate(_ url: URL, options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var bodyError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &coordinationError) { target in
            do { try body(target) } catch { bodyError = error }
        }
        if let error = (coordinationError as Error?) ?? bodyError { throw error }
    }
}

enum AutoBackupError: LocalizedError {
    case folderMissing

    var errorDescription: String? {
        switch self {
        case .folderMissing: "Le dossier de sauvegarde est introuvable : choisis-en un autre."
        }
    }
}

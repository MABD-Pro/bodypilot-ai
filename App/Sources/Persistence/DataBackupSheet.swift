import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// « Mes données » : exporter une sauvegarde dans un fichier, ou en restaurer une.
struct DataBackupSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var exportSummary = ""
    @State private var importing: ImportKind?
    @State private var pending: BackupArchive?
    @State private var message: String?
    @State private var isError = false
    @State private var autoFolder: String?
    @State private var lastAuto: Date?
    @State private var autoError: String?

    /// Un seul sélecteur de fichiers : deux sur la même vue se gênent.
    private enum ImportKind { case backup, folder }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Text("Tes données restent sur ton iPhone. Elles font partie de la sauvegarde iCloud de l'iPhone si elle est activée, mais seraient perdues si tu supprimais l'app. Un fichier de sauvegarde les garde à part.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Exporter mes données", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.s)
                        }
                        .buttonStyle(.glassProminent)
                        Text(exportSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    automatic

                    Button {
                        importing = .backup
                    } label: {
                        Label("Restaurer une sauvegarde", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.s)
                    }
                    .buttonStyle(.glass)

                    if let message {
                        CoachNote(text: message, tint: isError ? .orange : Theme.progress)
                    }

                    Text("Les données lues dans Santé (pesées de la balance, séances de la Watch, composition) y restent aussi : Santé les garde de son côté.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.xl)
            }
            .navigationTitle("Mes données")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .background { AppBackground() }
        }
        .task {
            prepareExport()
            refreshAutomatic()
        }
        .fileImporter(
            isPresented: Binding(get: { importing != nil }, set: { if !$0 { importing = nil } }),
            allowedContentTypes: importing == .folder ? [.folder] : [.json]
        ) { [importing] result in
            if importing == .folder { chooseFolder(result) } else { read(result) }
        }
        .confirmationDialog(
            "Remplacer toutes tes données ?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { archive in
            Button("Remplacer par la sauvegarde", role: .destructive) { restore(archive) }
        } message: { archive in
            Text("Sauvegarde du \(archive.exportedAt.formatted(.dateTime.day().month(.wide).year().locale(Theme.locale))) : \(archive.summary). Ce qui est dans l'app aujourd'hui sera remplacé.")
        }
    }

    /// Copie quotidienne dans un dossier choisi une fois.
    private var automatic: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Sauvegarde automatique")
                .font(.headline)
            if let autoFolder {
                Text("Chaque jour, une copie dans « \(autoFolder) ». Les \(AutoBackup.keptCopies) plus récentes sont gardées.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                if let lastAuto {
                    Text("Dernière copie : \(lastAuto.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute().locale(Theme.locale)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Changer de dossier") { importing = .folder }
                        .buttonStyle(.glass)
                    Button("Arrêter", role: .destructive) {
                        AutoBackup.disable()
                        refreshAutomatic()
                    }
                    .buttonStyle(.glass)
                }
            } else {
                Text("Choisis un dossier une fois, par exemple dans Fichiers ou sur un disque : BodyPilot y écrira une copie chaque jour et gardera les \(AutoBackup.keptCopies) plus récentes. Tu peux l'arrêter quand tu veux.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    importing = .folder
                } label: {
                    Label("Choisir un dossier", systemImage: "folder.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.s)
                }
                .buttonStyle(.glass)
            }
            if let autoError {
                CoachNote(text: autoError, tint: .orange)
            }
        }
    }

    private func chooseFolder(_ result: Result<URL, Error>) {
        do {
            try AutoBackup.enable(folder: result.get(), context: context)
        } catch {
            show("Ce dossier n'a pas pu être utilisé : \(error.localizedDescription)", isError: true)
        }
        refreshAutomatic()
    }

    private func refreshAutomatic() {
        autoFolder = AutoBackup.isOn ? AutoBackup.folderName ?? "ton dossier" : nil
        lastAuto = AutoBackup.lastBackup
        autoError = AutoBackup.lastError
    }

    /// Le fichier est écrit à l'ouverture : « Exporter » le partage aussitôt.
    private func prepareExport() {
        do {
            let archive = try Backup.archive(from: context)
            let url = FileManager.default.temporaryDirectory.appending(path: Backup.fileName())
            try Backup.encode(archive).write(to: url, options: .atomic)
            exportURL = url
            exportSummary = archive.summary + "."
        } catch {
            show("Impossible de préparer la sauvegarde : \(error.localizedDescription)", isError: true)
        }
    }

    private func read(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            // Fichier choisi hors de l'app : l'accès doit être demandé le temps de la lecture.
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let archive = try Backup.decode(Data(contentsOf: url))
            guard !archive.isEmpty else { throw BackupError.empty }
            pending = archive
        } catch is DecodingError {
            show("Ce fichier n'est pas une sauvegarde BodyPilot.", isError: true)
        } catch {
            show("Ce fichier n'a pas pu être lu : \(error.localizedDescription)", isError: true)
        }
    }

    private func restore(_ archive: BackupArchive) {
        do {
            try Backup.restore(archive, into: context)
            show("Sauvegarde restaurée : \(archive.summary).", isError: false)
            prepareExport()
        } catch {
            show("La restauration a échoué, tes données n'ont pas changé : \(error.localizedDescription)", isError: true)
        }
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        self.isError = isError
    }
}

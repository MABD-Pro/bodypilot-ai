import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// « Mes données » : exporter une sauvegarde dans un fichier, ou en restaurer une.
struct DataBackupSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var exportSummary = ""
    @State private var isImporting = false
    @State private var pending: BackupArchive?
    @State private var message: String?

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

                    Button {
                        isImporting = true
                    } label: {
                        Label("Restaurer une sauvegarde", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.s)
                    }
                    .buttonStyle(.glass)

                    if let message {
                        CoachNote(text: message, tint: Theme.progress)
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
        .task { prepareExport() }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            read(result)
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

    /// Le fichier est écrit à l'ouverture : « Exporter » le partage aussitôt.
    private func prepareExport() {
        do {
            let archive = try Backup.archive(from: context)
            let url = FileManager.default.temporaryDirectory.appending(path: Backup.fileName())
            try Backup.encode(archive).write(to: url, options: .atomic)
            exportURL = url
            exportSummary = archive.summary + "."
        } catch {
            message = "Impossible de préparer la sauvegarde : \(error.localizedDescription)"
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
        } catch {
            message = "Ce fichier n'a pas pu être lu : \(error.localizedDescription)"
        }
    }

    private func restore(_ archive: BackupArchive) {
        do {
            try Backup.restore(archive, into: context)
            message = "Sauvegarde restaurée : \(archive.summary)."
            prepareExport()
        } catch {
            message = "La restauration a échoué, tes données n'ont pas changé : \(error.localizedDescription)"
        }
    }
}

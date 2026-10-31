import BodyPilotCore
import Nutrition
import PhotosUI
import SwiftUI

/// Repas au restaurant : photographier la carte, le coach propose les plats les mieux adaptés
/// aux repères. Le texte est lu sur l'iPhone ; un plat choisi devient le repas décrit.
struct MenuScanSheet: View {
    let slot: MealSlot
    /// Repères du repas au restaurant.
    let target: Macros
    let choose: (DescribedMeal) -> Void
    /// Démo : lignes déjà lues, sans photo.
    var demoLines: [String]?

    @Environment(\.dismiss) private var dismiss
    @State private var pickedItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isReading = false
    @State private var picks: [MenuPick]?
    @State private var notRead = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Text("Prends la carte en photo : je repère les plats qui collent le mieux à tes repères du \(slot.title.lowercased()) (≈\u{00A0}\(target.kcal.frenchInteger)\u{00A0}kcal, \(target.proteinG.frenchInteger)\u{00A0}g de protéines). La photo reste sur ton iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    photoButtons
                    if isReading {
                        ProgressView("Lecture de la carte…")
                            .frame(maxWidth: .infinity)
                    } else if notRead {
                        CoachNote(text: "Je n'ai reconnu aucun plat. Reprends la photo bien à plat, de près, ou décris ton plat dans « Décrire ».", tint: Theme.nutrition)
                    } else if let picks {
                        results(picks)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .navigationTitle("Lire la carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await read(image)
                    }
                    pickedItem = nil
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    isShowingCamera = false
                    if let image { Task { await read(image) } }
                }
                .ignoresSafeArea()
            }
            .task {
                if let demoLines { show(MenuAdvisor.advise(lines: demoLines, target: target)) }
            }
        }
    }

    private var photoButtons: some View {
        HStack(spacing: Theme.Spacing.s) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Photographier", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.s)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Theme.nutrition.opacity(0.3)).interactive(), in: .capsule)
            }
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label("Photothèque", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.s)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .disabled(isReading)
    }

    @ViewBuilder
    private func results(_ picks: [MenuPick]) -> some View {
        Text(picks.count == 1 ? "Mon conseil" : "Mes \(picks.count) conseils")
            .font(.headline)
        ForEach(Array(picks.enumerated()), id: \.offset) { index, pick in
            pickRow(pick, isBest: index == 0)
        }
        Text("Estimations à partir des portions habituelles d'un restaurant. Tu pourras corriger les quantités dans « Décrire ».")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func pickRow(_ pick: MenuPick, isBest: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(pick.dish)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Theme.Spacing.s)
                if isBest {
                    Text("Recommandé")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.nutrition)
                }
            }
            Text("≈\u{00A0}\(pick.macros.kcal.frenchInteger)\u{00A0}kcal · \(pick.macros.proteinG.frenchInteger)\u{00A0}g de protéines")
                .font(.footnote.weight(.medium))
                .monospacedDigit()
            Label(pick.reason, systemImage: icon(pick.fit))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                choose(pick.meal)
                dismiss()
            } label: {
                Text("Je prends ça")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.glassProminent)
            .tint(isBest ? Theme.nutrition : .secondary)
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    private func icon(_ fit: MenuPick.Fit) -> String {
        switch fit {
        case .good: "checkmark.circle.fill"
        case .lowProtein: "bolt.heart"
        case .heavy: "scalemass"
        }
    }

    private func read(_ image: UIImage) async {
        withAnimation(Theme.springy) {
            isReading = true
            notRead = false
            picks = nil
        }
        let lines = await MenuReader.lines(in: image) ?? []
        show(MenuAdvisor.advise(lines: lines, target: target))
    }

    private func show(_ result: [MenuPick]) {
        withAnimation(Theme.springy) {
            isReading = false
            notRead = result.isEmpty
            picks = result.isEmpty ? nil : result
        }
    }
}

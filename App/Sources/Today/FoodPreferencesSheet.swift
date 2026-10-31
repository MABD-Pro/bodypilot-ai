import BodyPilotCore
import SwiftData
import SwiftUI

/// Ce que l'utilisateur ne veut pas voir dans ses repas proposés. Ses propres repas, décrits ou
/// habituels, ne sont jamais filtrés.
struct FoodPreferencesSheet: View {
    @Bindable var profileRecord: ProfileRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(FoodAversion.allCases, id: \.self) { aversion in
                        Toggle(aversion.label, isOn: binding(for: aversion))
                    }
                } header: {
                    Text("Sans")
                } footer: {
                    Text("Les repas proposés évitent ces aliments, ou les remplacent : tofu pour la viande, le poisson et les œufs, yaourt au soja pour les laitages, graines de courge pour les fruits à coque. En cas d'allergie, vérifie toujours les étiquettes.")
                }
                Section {
                    Text("Le coach apprend aussi de ce que tu décris : un repas noté au moins 3 jours en 4 semaines au même moment devient ta proposition, à la bonne portion. Sans quantité, un aliment prend ta portion habituelle.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Préférences alimentaires")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func binding(for aversion: FoodAversion) -> Binding<Bool> {
        Binding {
            profileRecord.avoidedFoods.contains(aversion)
        } set: { isOn in
            var avoided = profileRecord.avoidedFoods
            if isOn { avoided.insert(aversion) } else { avoided.remove(aversion) }
            profileRecord.avoidedFoods = avoided
        }
    }
}

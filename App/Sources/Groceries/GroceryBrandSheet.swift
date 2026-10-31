import Nutrition
import SwiftUI

/// Marques conseillées pour un article : la sélection embarquée, et la même recherche en direct
/// dans Open Food Facts quand l'utilisateur la demande.
struct GroceryBrandSheet: View {
    let item: GroceryItem
    /// Marque choisie auparavant, s'il y en a une.
    let chosen: String?
    let choose: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = SearchState.idle

    private enum SearchState: Equatable {
        case idle, loading, failed
        case done([GroceryBrandPick])
    }

    private var embedded: [GroceryBrandPick] { GroceryBrands.picks(for: item.name) }
    private var selected: String? { chosen ?? embedded.first?.brand }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if embedded.isEmpty {
                        Text("Pas encore de marque retenue pour cet article : lance la recherche ci-dessous.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(embedded) { pick in
                        pickRow(pick)
                    }
                } header: {
                    Text("Conseillées")
                }

                Section {
                    switch search {
                    case .idle:
                        searchButton("Chercher d'autres marques")
                    case .loading:
                        HStack(spacing: Theme.Spacing.m) {
                            ProgressView()
                            Text("Recherche dans Open Food Facts…")
                                .foregroundStyle(.secondary)
                        }
                    case .failed:
                        Label("Open Food Facts ne répond pas. Réessaie plus tard.", systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.secondary)
                        searchButton("Réessayer")
                    case .done(let picks):
                        let others = picks.filter { pick in !embedded.contains { $0.brand.lowercased() == pick.brand.lowercased() } }
                        if others.isEmpty {
                            Text("Aucune autre marque ne passe les critères.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(others) { pick in
                            pickRow(pick)
                        }
                    }
                } header: {
                    Text("En direct")
                } footer: {
                    Text("Choix : Nutri-Score d'abord, puis le produit le moins transformé (NOVA), le plus riche en protéines pour les sources de protéines, puis le plus courant. Seul le nom de l'article est envoyé. Données Open Food Facts, licence ODbL : vérifie l'étiquette en magasin.")
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func pickRow(_ pick: GroceryBrandPick) -> some View {
        let isSelected = pick.brand == selected
        return HStack(spacing: Theme.Spacing.m) {
            Button {
                choose(pick.brand)
                dismiss()
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    NutriScoreBadge(grade: pick.nutriScore)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pick.brand)
                            .font(.body.weight(.semibold))
                        Text(pick.product)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if let nova = pick.nova {
                            Text("NOVA \(nova) · \(Self.novaLabel(nova))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: Theme.Spacing.s)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.progress)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if let url = pick.url {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.nutrition)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Fiche Open Food Facts : \(pick.brand)")
            }
        }
    }

    private func searchButton(_ title: String) -> some View {
        Button(title, systemImage: "magnifyingglass") {
            Task { await runSearch() }
        }
        .foregroundStyle(Theme.nutrition)
    }

    private func runSearch() async {
        guard let query = GroceryBrands.query(for: item.name) else { return }
        search = .loading
        do {
            let picks = try await OpenFoodFactsSearch.picks(for: query)
            withAnimation(Theme.springy) { search = .done(picks) }
        } catch {
            withAnimation(Theme.springy) { search = .failed }
        }
    }

    private static func novaLabel(_ group: Int) -> String {
        switch group {
        case 1: "brut ou peu transformé"
        case 2: "ingrédient culinaire"
        case 3: "transformé"
        default: "ultra-transformé"
        }
    }
}

/// Pastille Nutri-Score aux couleurs officielles.
private struct NutriScoreBadge: View {
    let grade: String?

    var body: some View {
        Text(grade ?? "?")
            .font(.headline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(color.gradient, in: .rect(cornerRadius: 9))
            .accessibilityLabel(grade.map { "Nutri-Score \($0)" } ?? "Nutri-Score inconnu")
    }

    private var color: Color {
        switch grade {
        case "A": Color(red: 0.00, green: 0.51, blue: 0.25)
        case "B": Color(red: 0.52, green: 0.73, blue: 0.18)
        case "C": Color(red: 0.98, green: 0.75, blue: 0.00)
        case "D": Color(red: 0.93, green: 0.51, blue: 0.00)
        case "E": Color(red: 0.90, green: 0.24, blue: 0.07)
        default: .gray
        }
    }
}

/// Recherche en direct, lancée seulement à la demande : seul le nom générique de l'article part.
enum OpenFoodFactsSearch {
    static func picks(for query: GroceryBrandQuery) async throws -> [GroceryBrandPick] {
        guard let url = GroceryBrands.searchURL(for: query) else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(for: OpenFoodFacts.request(url, timeout: 20))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try GroceryBrands.picks(fromSearchResponse: data, for: query)
    }
}

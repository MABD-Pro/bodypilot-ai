import BodyPilotCore
import Nutrition
import SwiftUI

/// « Qu'as-tu vraiment mangé ? » en une phrase : le coach estime, demande une précision si besoin.
struct MealDescriptionSheet: View {
    let slot: MealSlot
    let save: (DescribedMeal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var parse: MealParse?
    /// Portion choisie pour chaque aliment dont la quantité était devinée (indice → facteur).
    @State private var portions: [Int: Double] = [:]
    /// Aliments retirés par l'utilisateur (indices dans l'estimation).
    @State private var removed: Set<Int> = []
    @State private var isAnalyzing = false
    @FocusState private var isEditing: Bool

    init(slot: MealSlot, initial: DescribedMeal?, save: @escaping (DescribedMeal) -> Void) {
        self.slot = slot
        self.save = save
        _text = State(initialValue: initial?.text ?? "")
        _parse = State(initialValue: initial.map { MealParse(text: $0.text, foods: $0.foods) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Qu'as-tu mangé \(slot.inTheMeal) ?")
                            .font(.display(26))
                        Text("Comme tu le dirais : « une grande assiette de pâtes carbo et un coca ».")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Ton repas", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($isEditing)
                        .submitLabel(.done)
                        .onSubmit { Task { await analyze() } }
                        .padding(Theme.Spacing.m)
                        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: Theme.Radius.inner))

                    if parse == nil || isEditing {
                        Button {
                            Task { await analyze() }
                        } label: {
                            Label(isAnalyzing ? "J'analyse…" : "Estimer", systemImage: "sparkles")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(slot.tint)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isAnalyzing)
                    }

                    if let parse {
                        result(parse)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        guard let meal else { return }
                        save(meal)
                        dismiss()
                    }
                    .disabled(meal == nil || isEditing)
                }
            }
        }
        .onAppear { if parse == nil { isEditing = true } }
        .onChange(of: text) { _, new in
            if new != parse?.text { parse = nil; portions = [:]; removed = [] }
        }
    }

    /// Repas à enregistrer : les aliments reconnus, avec les portions précisées.
    private var meal: DescribedMeal? {
        guard let parse else { return nil }
        let foods = kept(of: parse).map(\.food)
        return foods.isEmpty ? nil : DescribedMeal(text: parse.text, foods: foods)
    }

    /// Aliments gardés, avec leur indice d'origine et la portion précisée.
    private func kept(of parse: MealParse) -> [(index: Int, food: DescribedFood)] {
        parse.foods.enumerated().compactMap { index, food in
            guard !removed.contains(index) else { return nil }
            guard food.needsPortion, let factor = portions[index],
                  let choice = MealTextParser.portionChoices.first(where: { $0.factor == factor })
            else { return (index, food) }
            return (index, food.resized(by: factor, label: choice.factor == 1 ? "Portion normale" : "\(choice.label) portion"))
        }
    }

    @ViewBuilder
    private func result(_ parse: MealParse) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(kept(of: parse), id: \.index) { item in
                foodRow(item.food, question: parse.foods[item.index].needsPortion, index: item.index)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if !parse.unrecognized.isEmpty {
                CoachNote(
                    text: "Je ne connais pas « \(parse.unrecognized.joined(separator: " », « ")) ». Précise les aliments (« agneau, semoule, légumes ») ou une quantité en grammes.",
                    tint: slot.tint
                )
            }

            if let meal {
                HStack(alignment: .firstTextBaseline) {
                    Text("≈ \(meal.macros.kcal.frenchInteger) kcal")
                        .font(.display(24))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: meal.macros.kcal))
                    Spacer()
                    Text("P \(Int(meal.macros.proteinG.rounded())) · G \(Int(meal.macros.carbsG.rounded())) · L \(Int(meal.macros.fatG.rounded())) g")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Theme.Spacing.xs)
                Text("Une estimation, pas une pesée : la suite de ta journée s'ajuste à ce total.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func foodRow(_ food: DescribedFood, question: Bool, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(.subheadline.weight(.semibold))
                    Text(food.isEstimate ? "\(food.quantityLabel) · estimé" : food.quantityLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(food.macros.kcal.frenchInteger) kcal")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: food.macros.kcal))
                Button {
                    withAnimation(Theme.springy) { _ = removed.insert(index) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Retirer \(food.name)")
            }
            if question {
                Text("Quelle quantité ?")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(slot.tint)
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(MealTextParser.portionChoices, id: \.factor) { choice in
                        let isOn = portions[index] == choice.factor
                        Button {
                            withAnimation(Theme.springy) { portions[index] = choice.factor }
                        } label: {
                            Text(choice.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isOn ? Color.white : Color.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.s)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(isOn ? .regular.tint(slot.tint).interactive() : .regular.interactive(), in: .capsule)
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    private func analyze() async {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        isEditing = false
        isAnalyzing = true
        let result = await OnDeviceMealModel.describer().describe(input)
        withAnimation(Theme.springy) {
            parse = result
            portions = [:]
            removed = []
            isAnalyzing = false
        }
    }
}

extension MealSlot {
    /// « au petit-déjeuner », « à la collation »…
    var inTheMeal: String {
        switch self {
        case .breakfast: "au petit-déjeuner"
        case .lunch: "au déjeuner"
        case .snack: "à la collation"
        case .dinner: "au dîner"
        }
    }
}

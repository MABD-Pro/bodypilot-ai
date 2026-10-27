import BodyPilotCore
import SwiftUI

/// « Que dois-je manger aujourd'hui ? »
struct NutritionCard: View {
    let targets: NutritionTargets
    let meals: DayMealPlan

    @State private var expanded: MealSlot?
    @State private var showsRationale = false

    var body: some View {
        CoachCard(eyebrow: "Manger", symbol: "fork.knife", tint: Theme.nutrition) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(targets.macros.kcal.frenchInteger)
                    .font(.display(44))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: targets.macros.kcal))
                Text("kcal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(Theme.springy) { showsRationale.toggle() }
                } label: {
                    Image(systemName: showsRationale ? "xmark" : "info")
                        .font(.footnote.weight(.bold))
                        .frame(width: 30, height: 30)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Pourquoi ce chiffre ?")
            }

            if showsRationale {
                CoachNote(text: targets.rationale, tint: Theme.nutrition)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: Theme.Spacing.l) {
                MacroGauge(label: "Protéines", grams: targets.macros.proteinG, share: share(targets.macros.proteinG * 4), tint: Theme.protein)
                MacroGauge(label: "Glucides", grams: targets.macros.carbsG, share: share(targets.macros.carbsG * 4), tint: Theme.carbs)
                MacroGauge(label: "Lipides", grams: targets.macros.fatG, share: share(targets.macros.fatG * 9), tint: Theme.fat)
            }

            ForEach(meals.notes, id: \.self) { note in
                CoachNote(text: note, tint: Theme.nutrition)
            }

            VStack(spacing: Theme.Spacing.s) {
                ForEach(meals.meals, id: \.slot) { meal in
                    MealRow(meal: meal, isExpanded: expanded == meal.slot) {
                        withAnimation(Theme.springy) {
                            expanded = expanded == meal.slot ? nil : meal.slot
                        }
                    }
                }
            }
        }
    }

    /// Part des calories, pour dimensionner les jauges.
    private func share(_ kcal: Double) -> Double {
        targets.macros.kcal > 0 ? kcal / targets.macros.kcal : 0
    }
}

private struct MealRow: View {
    let meal: PlannedMeal
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Button(action: toggle) {
                HStack(spacing: Theme.Spacing.m) {
                    IconBadge(symbol: meal.isEatingOut ? "fork.knife" : meal.slot.symbol, tint: meal.isEatingOut ? Theme.nutrition : meal.slot.tint, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.slot.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(meal.title)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: Theme.Spacing.s)
                    Text("\(meal.isEatingOut ? "≈ " : "")\(meal.macros.kcal.frenchInteger) kcal")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(meal.items, id: \.name) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(item.quantityLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    Text("\(meal.isEatingOut ? "Vise ≈ " : "")\(Int(meal.macros.proteinG.rounded())) g de protéines")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.protein)
                        .padding(.top, 2)
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }
}

extension MealSlot {
    var title: String {
        switch self {
        case .breakfast: "Petit-déjeuner"
        case .lunch: "Déjeuner"
        case .snack: "Collation"
        case .dinner: "Dîner"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .snack: "carrot.fill"
        case .dinner: "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .breakfast: Theme.carbs
        case .lunch: Theme.nutrition
        case .snack: Theme.progress
        case .dinner: Theme.fat
        }
    }
}

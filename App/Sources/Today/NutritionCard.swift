import BodyPilotCore
import Nutrition
import SwiftUI

/// « Que dois-je manger aujourd'hui ? »
struct NutritionCard: View {
    let targets: NutritionTargets
    let meals: DayMealPlan
    var logIntake: (MealSlot, MealIntake?) -> Void = { _, _ in }
    /// Ouvre la saisie en texte de ce qui a vraiment été mangé.
    var describe: (MealSlot) -> Void = { _ in }
    /// Repas décrits ces 7 derniers jours, à reprendre d'une touche.
    var recent: (MealSlot) -> [RecentMeal] = { _ in [] }
    var reuse: (MealSlot, DescribedMeal) -> Void = { _, _ in }

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

            Text(eatenSummary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: eaten.kcal))

            HStack(spacing: Theme.Spacing.l) {
                MacroGauge(label: "Protéines", eaten: eaten.proteinG, target: targets.macros.proteinG, tint: Theme.protein)
                MacroGauge(label: "Glucides", eaten: eaten.carbsG, target: targets.macros.carbsG, tint: Theme.carbs)
                MacroGauge(label: "Lipides", eaten: eaten.fatG, target: targets.macros.fatG, tint: Theme.fat)
            }

            ForEach(meals.notes, id: \.self) { note in
                CoachNote(text: note, tint: Theme.nutrition)
            }

            VStack(spacing: Theme.Spacing.s) {
                ForEach(meals.meals, id: \.slot) { meal in
                    MealRow(
                        meal: meal,
                        isExpanded: expanded == meal.slot,
                        toggle: {
                            withAnimation(Theme.springy) {
                                expanded = expanded == meal.slot ? nil : meal.slot
                            }
                        },
                        log: { logIntake(meal.slot, $0) },
                        describe: { describe(meal.slot) },
                        recent: recent(meal.slot),
                        reuse: { reuse(meal.slot, $0) }
                    )
                }
            }
        }
    }

    private var eaten: Macros { meals.eatenTotals }

    /// « Objectif du jour », puis ce qui reste une fois des repas pris.
    private var eatenSummary: String {
        guard eaten.kcal > 0 else { return "Objectif du jour · rien de mangé pour l'instant" }
        let over = eaten.kcal - targets.macros.kcal
        // Le reste annoncé est celui des repas encore prévus, pour coller aux chiffres affichés.
        let planned = meals.meals.filter { !$0.isEaten }.reduce(0) { $0 + $1.macros.kcal }
        return over > 0
            ? "\(eaten.kcal.frenchInteger) kcal mangées · \(over.frenchInteger) au-dessus"
            : "\(eaten.kcal.frenchInteger) kcal mangées · reste \(planned.frenchInteger) prévues"
    }
}

private struct MealRow: View {
    let meal: PlannedMeal
    let isExpanded: Bool
    let toggle: () -> Void
    /// Repas pris : une touche pour « comme prévu », le détail dans la vue dépliée.
    let log: (MealIntake?) -> Void
    let describe: () -> Void
    let recent: [RecentMeal]
    let reuse: (DescribedMeal) -> Void

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
                    Text("\(meal.isEatingOut || meal.isEaten ? "≈ " : "")\(meal.macros.kcal.frenchInteger) kcal")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: meal.macros.kcal))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .opacity(meal.isEaten ? 0.7 : 1)

            HStack(spacing: Theme.Spacing.s) {
                if meal.described != nil {
                    Label("Ce que j'ai mangé", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.progress)
                    Spacer()
                    Button("Modifier", action: describe)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(meal.slot.tint)
                    Button("Annuler") { log(nil) }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else if let intake = meal.intake {
                    Label(intake.label, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.progress)
                    Spacer()
                    Button("Annuler") { log(nil) }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else {
                    // Sur un écran étroit, « Décrire » et « Reprendre » passent en icônes.
                    ViewThatFits(in: .horizontal) {
                        pendingActions(iconOnly: false)
                        pendingActions(iconOnly: true)
                    }
                }
            }
            .padding(.leading, 50)
            .sensoryFeedback(.success, trigger: meal.isEaten) { _, new in new }

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
                    Text("\(meal.isEatingOut ? "Vise ≈ " : meal.described != nil ? "≈ " : "")\(Int(meal.macros.proteinG.rounded())) g de protéines")
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

extension MealRow {
    /// Repas pas encore noté : comme prévu, décrit, repris d'un jour récent ou autrement.
    func pendingActions(iconOnly: Bool) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                log(.asPlanned)
            } label: {
                Label("Comme prévu", systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(meal.slot.tint)
            .fixedSize()
            Spacer(minLength: 0)
            Button(action: describe) {
                Label("Décrire", systemImage: "square.and.pencil")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .labelStyle(CompactLabelStyle(iconOnly: iconOnly))
            }
            .buttonStyle(.plain)
            .foregroundStyle(meal.slot.tint)
            .accessibilityLabel("Décrire ce que j'ai mangé")
            .fixedSize()
            if !recent.isEmpty {
                Menu {
                    ForEach(recent, id: \.meal.title) { item in
                        Button {
                            reuse(item.meal)
                        } label: {
                            Text(item.meal.title)
                            Text("\(Self.dayLabel(item.day)), \(item.slot.title.lowercased()) · \(item.meal.macros.kcal.frenchInteger) kcal")
                        }
                    }
                } label: {
                    Label("Reprendre", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .labelStyle(CompactLabelStyle(iconOnly: iconOnly))
                }
                .foregroundStyle(meal.slot.tint)
                .accessibilityLabel("Reprendre un repas récent")
                .fixedSize()
            }
            Menu {
                ForEach([MealIntake.skipped, .light, .hearty, .veryHearty], id: \.self) { intake in
                    Button(intake.label) { log(intake) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Autrement")
            }
        }
    }

    /// « Hier », « Lundi » : le jour d'un repas récent.
    static func dayLabel(_ day: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInYesterday(day) { return "Hier" }
        return day.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "fr_FR"))).capitalized
    }
}

/// Libellé complet, ou l'icône seule quand la place manque. « Comme prévu », l'action
/// principale, garde ses mots.
private struct CompactLabelStyle: LabelStyle {
    let iconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            if !iconOnly { configuration.title }
        }
    }
}

extension MealIntake {
    var label: String {
        switch self {
        case .skipped: "Sauté"
        case .light: "Plus léger que prévu"
        case .asPlanned: "Mangé comme prévu"
        case .hearty: "Plus copieux"
        case .veryHearty: "Beaucoup plus copieux"
        }
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

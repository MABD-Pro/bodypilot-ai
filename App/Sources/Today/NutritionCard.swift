import BodyPilotCore
import Nutrition
import SwiftUI

/// « Que dois-je manger aujourd'hui ? »
struct NutritionCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let targets: NutritionTargets
    let meals: DayMealPlan
    var logIntake: (MealSlot, MealIntake?) -> Void = { _, _ in }
    /// Ouvre la saisie en texte de ce qui a vraiment été mangé.
    var describe: (MealSlot) -> Void = { _ in }
    /// Repas décrits ces 7 derniers jours, à reprendre d'une touche.
    var recent: (MealSlot) -> [RecentMeal] = { _ in [] }
    var reuse: (MealSlot, DescribedMeal) -> Void = { _, _ in }
    /// Historique des repas : tous (`nil`), ou ceux d'un moment de la journée.
    var showHistory: ((MealSlot?) -> Void)?
    /// Ouvre la liste de courses des prochains jours.
    var showGroceries: (() -> Void)?
    /// Jour passé corrigé depuis l'historique : ce qui a été mangé, sans conseils pour la suite.
    var pastDay = false

    @State private var expanded: MealSlot?
    @State private var showsRationale = false

    var body: some View {
        CoachCard(eyebrow: "Manger", symbol: "fork.knife", tint: Theme.nutrition, history: showHistory.map { show in { show(nil) } }) {
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

            NutrientGauges(eaten: eaten, target: targets.macros)

            // Les notes parlent du reste de la journée : rien à en tirer pour un jour passé.
            if !pastDay {
                ForEach(meals.notes, id: \.self) { note in
                    CoachNote(text: note, tint: Theme.nutrition)
                }
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
                        reuse: { reuse(meal.slot, $0) },
                        showHistory: showHistory.map { show in { show(meal.slot) } },
                        pastDay: pastDay
                    )
                }
            }

            if let showGroceries {
                Button(action: showGroceries) {
                    HStack(spacing: Theme.Spacing.m) {
                        Image(systemName: "cart.fill")
                            .font(.subheadline.weight(.bold))
                        Text("Préparer mes courses")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Theme.Spacing.s)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.m)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.nutrition)
                .glassEffect(.regular.tint(Theme.nutrition.opacity(0.12)).interactive(), in: .capsule)
            }
        }
    }

    private var eaten: Macros { meals.eatenTotals }

    /// « Objectif du jour », puis ce qui reste une fois des repas pris.
    private var eatenSummary: String {
        if pastDay {
            let noted = meals.meals.filter(\.isEaten).count
            guard noted > 0 else { return "Objectif de ce jour · aucun repas noté" }
            return "\(eaten.kcal.frenchInteger) kcal mangées · \(noted) repas sur \(meals.meals.count) notés"
        }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let meal: PlannedMeal
    let isExpanded: Bool
    let toggle: () -> Void
    /// Repas pris : une touche pour « comme prévu », le détail dans la vue dépliée.
    let log: (MealIntake?) -> Void
    let describe: () -> Void
    let recent: [RecentMeal]
    let reuse: (DescribedMeal) -> Void
    var showHistory: (() -> Void)?
    var pastDay = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Button(action: toggle) {
                HStack(spacing: Theme.Spacing.m) {
                    // Très grand texte : sans icône et avec les kcal sous le titre, le nom du repas
                    // garde toute la largeur au lieu d'être coupé syllabe par syllabe.
                    if !dynamicTypeSize.isAccessibilitySize {
                        IconBadge(symbol: meal.isEatingOut ? "fork.knife" : meal.slot.symbol, tint: meal.isEatingOut ? Theme.nutrition : meal.slot.tint, size: 38)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.slot.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(meal.title)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        if dynamicTypeSize.isAccessibilitySize { kcalLabel }
                    }
                    Spacer(minLength: Theme.Spacing.s)
                    if !dynamicTypeSize.isAccessibilitySize { kcalLabel }
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
                    // Très grand texte : les actions s'empilent plutôt que d'élargir tout l'écran.
                    ViewThatFits(in: .horizontal) {
                        pendingActions(iconOnly: false)
                        pendingActions(iconOnly: true)
                        pendingActions(iconOnly: false, stacked: true)
                    }
                }
            }
            .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 50)
            .sensoryFeedback(.success, trigger: meal.isEaten) { _, new in new }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Par position : un repas décrit peut citer deux fois le même aliment.
                    ForEach(Array(meal.items.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(item.quantityLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    if meal.isEatingOut {
                        Text("Repères à viser")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    NutrientBreakdown(macros: meal.macros, approximate: meal.isEatingOut || meal.described != nil)
                        .padding(.top, 2)
                    // Un jour passé garde ce qui a été mangé : pas de version allégée à proposer.
                    if let described = meal.described, !pastDay {
                        improvements(for: described)
                    }
                    if let showHistory {
                        Button(action: showHistory) {
                            Label("Historique : \(meal.slot.title.lowercased())", systemImage: "clock.arrow.circlepath")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(meal.slot.tint)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }
}

extension MealRow {
    /// Repas décrit : les mêmes suggestions que dans « Décrire », applicables d'une touche.
    @ViewBuilder
    func improvements(for described: DescribedMeal) -> some View {
        let suggestions = MealImprover.suggestions(for: described, slot: meal.slot)
        if suggestions.isEmpty {
            Label("Repas équilibré : rien à changer", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.progress)
                .padding(.top, 2)
        } else {
            ForEach(suggestions) { suggestion in
                Button {
                    reuse(suggestion.meal)
                } label: {
                    Label {
                        Text("\(suggestion.title) · \(suggestion.effect)")
                            .multilineTextAlignment(.leading)
                    } icon: {
                        Image(systemName: suggestion.goal == .lighter ? "leaf.fill" : "bolt.heart.fill")
                            .foregroundStyle(suggestion.goal == .lighter ? Theme.progress : Theme.protein)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(meal.slot.tint)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityHint("Remplace ce repas par la version proposée")
            }
        }
    }

    var kcalLabel: some View {
        Text("\(meal.isEatingOut || meal.isEaten ? "≈ " : "")\(meal.macros.kcal.frenchInteger) kcal")
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .contentTransition(.numericText(value: meal.macros.kcal))
    }

    /// Repas pas encore noté : comme prévu, décrit, repris d'un jour récent ou autrement.
    func pendingActions(iconOnly: Bool, stacked: Bool = false) -> some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.m))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.m))
        return layout {
            Button {
                log(.asPlanned)
            } label: {
                Label("Comme prévu", systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .lineLimit(stacked ? nil : 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(meal.slot.tint)
            .fixedSize(horizontal: !stacked, vertical: true)
            if !stacked { Spacer(minLength: 0) }
            Button(action: describe) {
                Label("Décrire", systemImage: "square.and.pencil")
                    .font(.caption.weight(.semibold))
                    .lineLimit(stacked ? nil : 1)
                    .labelStyle(CompactLabelStyle(iconOnly: iconOnly))
            }
            .buttonStyle(.plain)
            .foregroundStyle(meal.slot.tint)
            .accessibilityLabel("Décrire ce que j'ai mangé")
            .fixedSize(horizontal: !stacked, vertical: true)
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
                        .lineLimit(stacked ? nil : 1)
                        .labelStyle(CompactLabelStyle(iconOnly: iconOnly))
                }
                .foregroundStyle(meal.slot.tint)
                .accessibilityLabel("Reprendre un repas récent")
                .fixedSize(horizontal: !stacked, vertical: true)
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

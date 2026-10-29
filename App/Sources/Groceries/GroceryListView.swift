import BodyPilotCore
import Nutrition
import SwiftUI

/// Liste de courses des prochains jours : ce que demandent les repas proposés par le coach,
/// rangé par rayon, à cocher en magasin et à partager.
struct GroceryListView: View {
    /// Objectifs du jour : les portions des jours suivants sont calculées avec eux.
    let targets: NutritionTargets
    let profile: UserProfile

    /// Liste en cours, gardée sur l'iPhone d'une ouverture à l'autre (rien d'essentiel : pas de base).
    @AppStorage("groceryList") private var stored = Data()
    @State private var newItem = ""
    @FocusState private var isAdding: Bool

    private let calendar = Calendar.current

    var body: some View {
        let state = GroceryState.decoded(from: stored)
        let days = state.days(calendar: calendar)
        let list = MealPlanner().groceries(for: targets, profile: profile, days: days, slots: Set(state.slots))
        let toBuy = list.items.filter { !state.atHome.contains($0.id) }
        let home = list.items.filter { state.atHome.contains($0.id) }
        let remaining = toBuy.filter { !state.checked.contains($0.id) }.count
            + state.extras.filter { !state.checked.contains($0.id) }.count

        List {
            Section {
                summary(state: state, days: days, list: list, remaining: remaining, total: toBuy.count + state.extras.count)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if list.items.isEmpty {
                Section {
                    Text("Choisis au moins un repas à préparer.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(list.sections) { section in
                let items = section.items.filter { !state.atHome.contains($0.id) }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            row(item, isChecked: state.checked.contains(item.id))
                                .swipeActions(edge: .trailing) {
                                    Button("J'en ai déjà", systemImage: "house.fill") {
                                        update { $0.atHome.insert(item.id); $0.checked.remove(item.id) }
                                    }
                                    .tint(Theme.progress)
                                }
                                .contextMenu {
                                    Button("J'en ai déjà", systemImage: "house") {
                                        update { $0.atHome.insert(item.id); $0.checked.remove(item.id) }
                                    }
                                }
                        }
                    } header: {
                        Label(section.aisle.title, systemImage: section.aisle.symbol)
                            .foregroundStyle(Theme.nutrition)
                    }
                }
            }

            Section {
                ForEach(state.extras) { extra in
                    extraRow(extra, isChecked: state.checked.contains(extra.id))
                        .swipeActions(edge: .trailing) {
                            Button("Retirer", systemImage: "trash", role: .destructive) {
                                update { $0.extras.removeAll { $0.id == extra.id }; $0.checked.remove(extra.id) }
                            }
                        }
                }
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.nutrition)
                    TextField("Ajouter un article", text: $newItem)
                        .focused($isAdding)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                }
            } header: {
                Label("Mes ajouts", systemImage: "square.and.pencil")
                    .foregroundStyle(Theme.nutrition)
            }

            if !home.isEmpty {
                Section {
                    ForEach(home) { item in
                        Button {
                            update { $0.atHome.remove(item.id) }
                        } label: {
                            HStack {
                                Text(item.name)
                                Spacer()
                                Label("Remettre", systemImage: "arrow.uturn.backward")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.nutrition)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Déjà à la maison", systemImage: "house")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Quantités calculées avec tes objectifs d'aujourd'hui, pour les repas que le coach propose ces jours-là, arrondies à ce qui s'achète. Un repas au restaurant ou remplacé en laisse un peu : il servira la semaine suivante.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .navigationTitle("Liste de courses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText(state: state, days: days, items: toBuy)) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Options", systemImage: "ellipsis") {
                    Button("Tout décocher", systemImage: "circle") {
                        update { $0.checked = [] }
                    }
                    .disabled(state.checked.isEmpty)
                    Button("Nouvelle liste à partir de demain", systemImage: "arrow.clockwise") {
                        update { $0 = GroceryState(days: $0.dayCount, slots: $0.slots) }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: state.checked)
        .onAppear {
            // Première ouverture, ou période passée : la liste repart de demain.
            if state.start == nil || state.isOver(calendar: calendar) {
                update { $0 = GroceryState(days: $0.dayCount, slots: $0.slots) }
            }
        }
    }

    private func summary(state: GroceryState, days: [Date], list: GroceryList, remaining: Int, total: Int) -> some View {
        CoachCard(eyebrow: "Mes courses", symbol: "cart.fill", tint: Theme.nutrition) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    Text("\(remaining)")
                        .font(.display(44))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(remaining)))
                    Text(remaining > 1 ? "articles à prendre" : "article à prendre")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(periodLabel(days) + " · \(list.mealCount) repas")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if total > 0 {
                ProgressView(value: Double(total - remaining), total: Double(total))
                    .tint(Theme.progress)
                    .animation(Theme.springy, value: remaining)
            }

            Picker("Nombre de jours", selection: Binding(
                get: { state.dayCount },
                set: { count in update { $0.dayCount = count } }
            )) {
                ForEach(GroceryState.dayChoices, id: \.self) { count in
                    Text("\(count) jours").tag(count)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Repas à prévoir")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(MealSlot.allCases, id: \.self) { slot in
                        slotChip(slot, isOn: state.slots.contains(slot))
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.s)
    }

    private func slotChip(_ slot: MealSlot, isOn: Bool) -> some View {
        Button {
            update { state in
                if isOn { state.slots.removeAll { $0 == slot } } else { state.slots.append(slot) }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: slot.symbol)
                    .font(.footnote.weight(.bold))
                Text(slot.shortTitle)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s)
            .foregroundStyle(isOn ? .white : slot.tint)
            .background(isOn ? AnyShapeStyle(slot.tint.gradient) : AnyShapeStyle(slot.tint.opacity(0.12)), in: .rect(cornerRadius: Theme.Radius.inner))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(slot.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func row(_ item: GroceryItem, isChecked: Bool) -> some View {
        Button {
            update { $0.toggle(item.id) }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                checkmark(isChecked)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .strikethrough(isChecked)
                        .foregroundStyle(isChecked ? .secondary : .primary)
                    Text(([item.mealCount > 1 ? "\(item.mealCount) repas" : "1 repas"] + [item.detail].compactMap { $0 }).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.s)
                Text(item.quantityLabel)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isChecked ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.nutrition))
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }

    private func extraRow(_ extra: GroceryExtra, isChecked: Bool) -> some View {
        Button {
            update { $0.toggle(extra.id) }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                checkmark(isChecked)
                Text(extra.name)
                    .font(.body.weight(.medium))
                    .strikethrough(isChecked)
                    .foregroundStyle(isChecked ? .secondary : .primary)
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }

    private func checkmark(_ isChecked: Bool) -> some View {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isChecked ? Theme.progress : Color.secondary)
            .contentTransition(.symbolEffect(.replace))
    }

    private func addItem() {
        let name = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        update { $0.extras.append(GroceryExtra(name: name)) }
        newItem = ""
        isAdding = true
    }

    private func update(_ change: (inout GroceryState) -> Void) {
        var state = GroceryState.decoded(from: stored)
        withAnimation(Theme.springy) {
            change(&state)
            stored = state.encoded
        }
    }

    /// « Du vendredi 30 oct. au jeudi 5 nov. »
    private func periodLabel(_ days: [Date]) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        let style = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Theme.locale)
        return "Du \(first.formatted(style)) au \(last.formatted(style))"
    }

    /// Texte à envoyer (Messages, Rappels, Notes) : ce qui reste à acheter, par rayon.
    private func shareText(state: GroceryState, days: [Date], items: [GroceryItem]) -> String {
        var lines = ["Liste de courses · \(periodLabel(days).lowercased())"]
        for section in GroceryList(items: items, mealCount: 0).sections {
            let left = section.items.filter { !state.checked.contains($0.id) }
            guard !left.isEmpty else { continue }
            lines.append("")
            lines.append(section.aisle.title)
            lines += left.map { "• \($0.name) : \($0.quantityLabel)" }
        }
        let extras = state.extras.filter { !state.checked.contains($0.id) }
        if !extras.isEmpty {
            lines.append("")
            lines.append("Autres")
            lines += extras.map { "• \($0.name)" }
        }
        return lines.joined(separator: "\n")
    }
}

/// Ce que l'utilisateur a fait de la liste : période, repas choisis, articles cochés et ajoutés.
struct GroceryState: Codable, Equatable {
    static let dayChoices = [3, 5, 7]

    /// Premier jour de la liste (à midi), fixé à la création : la liste ne glisse pas d'un jour à l'autre.
    var start: Date?
    var dayCount = 7
    var slots: [MealSlot] = MealSlot.allCases
    /// Articles cochés : noms des aliments, ou identifiants des ajouts.
    var checked: Set<String> = []
    /// Aliments déjà à la maison, retirés de la liste.
    var atHome: Set<String> = []
    var extras: [GroceryExtra] = []

    mutating func toggle(_ id: String) {
        if checked.remove(id) == nil { checked.insert(id) }
    }

    init(days: Int = 7, slots: [MealSlot] = MealSlot.allCases, calendar: Calendar = .current, now: Date = .now) {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        start = calendar.storedDay(for: tomorrow)
        dayCount = days
        self.slots = slots
    }

    func days(calendar: Calendar) -> [Date] {
        let first = start ?? calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        return (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    /// Le dernier jour de la liste est passé.
    func isOver(calendar: Calendar, now: Date = .now) -> Bool {
        guard let last = days(calendar: calendar).last else { return true }
        return calendar.startOfDay(for: last) < calendar.startOfDay(for: now)
    }

    static func decoded(from data: Data) -> GroceryState {
        guard !data.isEmpty, let state = try? JSONDecoder().decode(GroceryState.self, from: data) else {
            var empty = GroceryState()
            empty.start = nil
            return empty
        }
        return state
    }

    var encoded: Data { (try? JSONEncoder().encode(self)) ?? Data() }
}

struct GroceryExtra: Codable, Equatable, Identifiable {
    var id = "ajout-" + UUID().uuidString
    var name: String
}

extension GroceryAisle {
    var symbol: String {
        switch self {
        case .produce: "carrot.fill"
        case .meatAndFish: "fish.fill"
        case .dairy: "refrigerator.fill"
        case .bakery: "basket.fill"
        case .pantry: "cabinet.fill"
        }
    }
}

extension MealSlot {
    /// Libellé court pour les pastilles (« Petit-déj »).
    var shortTitle: String {
        switch self {
        case .breakfast: "Petit-déj"
        case .lunch: "Déjeuner"
        case .snack: "Collation"
        case .dinner: "Dîner"
        }
    }
}

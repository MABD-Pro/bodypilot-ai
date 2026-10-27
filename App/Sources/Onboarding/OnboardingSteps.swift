import BodyPilotCore
import SwiftUI

struct BodyStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Picker("Sexe", selection: $draft.sex) {
                Text("Homme").tag(BiologicalSex.male)
                Text("Femme").tag(BiologicalSex.female)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, Theme.Spacing.s)

            SliderRow(title: "Âge", value: $draft.age, range: 16...85, step: 1, unit: "ans", decimals: false)
            SliderRow(title: "Taille", value: $draft.heightCm, range: 140...210, step: 1, unit: "cm", decimals: false)
            SliderRow(title: "Poids", value: $draft.weightKg, range: 40...180, step: 0.5, unit: "kg", decimals: true)
            SliderRow(title: "Poids visé", value: $draft.targetWeightKg, range: 40...180, step: 0.5, unit: "kg", decimals: true)
            Text("Je règle le déficit sur l'écart à ce poids : plus marqué au début, nul une fois arrivé. Protéines hautes et force pour garder, voire gagner, du muscle.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RhythmStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Au quotidien, hors sport").font(.headline)
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    ChoiceCard(title: level.title, subtitle: level.subtitle, symbol: level.symbol, tint: Theme.progress, isSelected: draft.activity == level, compact: true) {
                        withAnimation(Theme.springy) { draft.activity = level }
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Tes jours de séance habituels").font(.headline)
                WeekdayPicker(selected: $draft.trainingWeekdays)
                Text("Tu pourras les changer chaque semaine depuis l'écran Aujourd'hui.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Durée d'une séance").font(.headline)
                Picker("Durée d'une séance", selection: $draft.sessionMinutes) {
                    ForEach([20, 30, 45, 60], id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Où t'entraînes-tu ?").font(.headline)
                HStack(spacing: Theme.Spacing.m) {
                    ChoiceCard(title: "Maison", subtitle: "Poids du corps", symbol: "house.fill", tint: Theme.training, isSelected: draft.equipment == .bodyweight, compact: true) {
                        withAnimation(Theme.springy) { draft.equipment = .bodyweight }
                    }
                    ChoiceCard(title: "Salle", subtitle: "Haltères, machines", symbol: "dumbbell.fill", tint: Theme.training, isSelected: draft.equipment == .gym, compact: true) {
                        withAnimation(Theme.springy) { draft.equipment = .gym }
                    }
                }
            }
        }
    }
}

/// Jours de la semaine à cocher ; au moins un reste sélectionné.
struct WeekdayPicker: View {
    @Binding var selected: [Int]

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 6) {
            ForEach(calendar.orderedWeekdays, id: \.self) { weekday in
                let isOn = selected.contains(weekday)
                Button {
                    withAnimation(Theme.springy) {
                        if isOn {
                            if selected.count > 1 { selected.removeAll { $0 == weekday } }
                        } else {
                            selected = (selected + [weekday]).sorted()
                        }
                    }
                } label: {
                    Text(calendar.initialWeekdayLetters(locale: Theme.locale)[weekday - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(isOn ? Color.white : .secondary)
                        .background(isOn ? Theme.training : Theme.training.opacity(0.08), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(calendar.weekdayNames(locale: Theme.locale)[weekday - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// Carte de choix en verre, teintée quand elle est sélectionnée.
struct ChoiceCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let isSelected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(symbol: symbol, tint: tint, size: compact ? 34 : 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(compact ? .subheadline.weight(.semibold) : .headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(compact ? Theme.Spacing.m : Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(tint.opacity(0.25)).interactive() : .regular.interactive(), in: .rect(cornerRadius: Theme.Radius.inner + 4))
    }
}

/// Curseur avec grande valeur lisible : plus rapide qu'un clavier.
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let decimals: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(decimals ? value.frenchOneDecimal : value.frenchInteger)
                    .font(.display(26))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: value))
                Text(unit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .tint(Theme.nutrition)
        }
        .padding(Theme.Spacing.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.inner + 4))
    }
}

extension ActivityLevel {
    var title: String {
        switch self {
        case .sedentary: "Plutôt assis"
        case .light: "Un peu actif"
        case .moderate: "Actif"
        case .active: "Très actif"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: "Bureau, peu de marche"
        case .light: "Quelques trajets à pied"
        case .moderate: "Debout souvent, 8 000 pas et plus"
        case .active: "Métier physique"
        }
    }

    var symbol: String {
        switch self {
        case .sedentary: "chair.lounge.fill"
        case .light: "figure.walk"
        case .moderate: "figure.walk.motion"
        case .active: "figure.run"
        }
    }
}

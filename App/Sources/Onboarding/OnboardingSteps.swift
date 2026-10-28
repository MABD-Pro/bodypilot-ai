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
            Text("Le déficit suit l'écart à ce poids et s'arrête une fois arrivé.")
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

/// Le point de départ : comment le coach trouve tes charges, et le test à refaire après une pause.
struct StartStep: View {
    let equipment: Equipment
    /// `nil` à l'inscription ; en modification du profil, relance le test de force.
    var redoStrengthTest: (() -> Void)?

    @State private var isRedone = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if equipment == .gym {
                point(symbol: "scalemass.fill", title: "Deux séances de test", text: "Au premier jour de force, la séance s'appelle « Test de force 1/2 » : squat, développé couché, rowing. Le « 2/2 » suit au moins 48 h plus tard : soulevé de terre, développé militaire, tirage vertical.")
                point(symbol: "chart.line.uptrend.xyaxis", title: "Une série de 5, lourde mais propre", text: "Pour chaque mouvement, quelques paliers légers puis des essais de 5 répétitions de plus en plus lourds. Tu t'arrêtes quand la 5e devient difficile. Pas de charge maximale : c'est plus sûr et aussi fiable.")
                point(symbol: "dumbbell.fill", title: "Tes charges en découlent", text: "Le coach en tire tes charges de travail, et celles des variantes (haltères, machines). Elles montent ensuite séance après séance.")
                point(symbol: "moon.zzz.fill", title: "Seulement en forme", text: "Fatigué, genou sensible ou peu de temps : le test attend un meilleur jour, et le coach te dit pourquoi.")
                if let redoStrengthTest {
                    Button {
                        redoStrengthTest()
                        withAnimation(Theme.springy) { isRedone = true }
                    } label: {
                        Label(isRedone ? "Le test revient au prochain jour de force" : "Refaire le test de force", systemImage: isRedone ? "checkmark.circle.fill" : "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.training)
                    .disabled(isRedone)
                    .padding(.top, Theme.Spacing.s)
                    Text("Utile après une pause, une blessure ou un gros changement de forme. Tes records restent : le test repart de tes dernières charges.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                point(symbol: "figure.strengthtraining.functional", title: "Pas de test à la maison", text: "Au poids du corps, le coach part de répétitions simples et te fait progresser en répétitions et en variantes plus dures.")
                point(symbol: "dumbbell.fill", title: "À la salle, un test de force", text: "Si tu passes en salle dans ton profil, deux séances de test fixeront tes charges de départ.")
            }
        }
        .sensoryFeedback(.success, trigger: isRedone)
    }

    private func point(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            IconBadge(symbol: symbol, tint: Theme.training, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.inner + 4))
    }
}

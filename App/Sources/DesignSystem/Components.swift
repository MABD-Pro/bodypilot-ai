import BodyPilotCore
import SwiftUI

/// Carte principale : une question du jour, sa réponse, en verre.
struct CoachCard<Content: View>: View {
    let eyebrow: String
    let symbol: String
    let tint: Color
    /// Ouvre l'historique de cette partie, depuis l'en-tête de la carte.
    var history: (() -> Void)?
    let content: Content

    init(eyebrow: String, symbol: String, tint: Color, history: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.symbol = symbol
        self.tint = tint
        self.history = history
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack {
                Label {
                    Text(eyebrow)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.8)
                } icon: {
                    Image(systemName: symbol)
                        .font(.footnote.weight(.bold))
                }
                Spacer()
                if let history {
                    Button(action: history) {
                        Label("Historique", systemImage: "clock.arrow.circlepath")
                            .font(.footnote.weight(.semibold))
                            .labelStyle(.iconOnly)
                            .frame(width: 32, height: 32)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Historique : \(eyebrow.lowercased())")
                }
            }
            .foregroundStyle(tint)

            content
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.card))
    }
}

/// Pastille d'icône colorée.
struct IconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: .rect(cornerRadius: size * 0.32))
    }
}

/// Jauge de macronutriment : mangé sur objectif du jour, la barre se remplit au fil des repas.
struct MacroGauge: View {
    let label: String
    let eaten: Double
    let target: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(eaten.rounded()))")
                    .font(.display(17, weight: .semibold))
                    .contentTransition(.numericText(value: eaten))
                Text("/ \(Int(target.rounded())) g")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            Capsule()
                .fill(tint.opacity(0.18))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(tint.gradient)
                            .frame(width: eaten > 0 ? max(6, proxy.size.width * min(eaten / max(target, 1), 1)) : 0)
                    }
                }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(Int(eaten.rounded())) grammes sur \(Int(target.rounded()))")
    }
}

/// Les quatre nutriments du jour, mangé sur objectif, avec la part des calories de chacun
/// (protéines, glucides, lipides). Deux colonnes : les chiffres restent lisibles sur un iPhone étroit.
struct NutrientGauges: View {
    let eaten: Macros
    let target: Macros

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Grid(horizontalSpacing: Theme.Spacing.l, verticalSpacing: Theme.Spacing.m) {
                GridRow {
                    gauge(.protein)
                    gauge(.carbs)
                }
                GridRow {
                    gauge(.fat)
                    gauge(.fiber)
                }
            }
            if eaten.kcal > 0 {
                Text("En % : part des calories mangées.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func gauge(_ nutrient: Nutrient) -> some View {
        let share = eaten.energyShare(of: nutrient)
        return MacroGauge(
            label: share.map { "\(nutrient.title) · \(Int(($0 * 100).rounded())) %" } ?? nutrient.title,
            eaten: eaten.grams(of: nutrient),
            target: target.grams(of: nutrient),
            tint: nutrient.tint
        )
    }
}

/// Détail d'un repas : grammes de chaque nutriment et part des calories.
struct NutrientBreakdown: View {
    let macros: Macros
    /// « ≈ » devant les grammes : repas estimé ou repères du restaurant.
    var approximate = false

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.s, verticalSpacing: 2) {
            GridRow {
                ForEach(Nutrient.allCases, id: \.self) { nutrient in
                    Text("\(approximate ? "≈ " : "")\(Int(macros.grams(of: nutrient).rounded())) g")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(nutrient.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            GridRow {
                ForEach(Nutrient.allCases, id: \.self) { nutrient in
                    Text(caption(nutrient))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Nutrient.allCases.map { "\($0.title) : \(Int(macros.grams(of: $0).rounded())) grammes" }.joined(separator: ", "))
    }

    private func caption(_ nutrient: Nutrient) -> String {
        guard let share = macros.energyShare(of: nutrient) else { return nutrient.shortTitle }
        return "\(nutrient.shortTitle) · \(Int((share * 100).rounded())) %"
    }
}

extension Nutrient {
    var title: String {
        switch self {
        case .protein: "Protéines"
        case .carbs: "Glucides"
        case .fat: "Lipides"
        case .fiber: "Fibres"
        }
    }

    var shortTitle: String {
        switch self {
        case .protein: "Prot."
        case .carbs: "Gluc."
        case .fat: "Lip."
        case .fiber: "Fibres"
        }
    }

    var tint: Color {
        switch self {
        case .protein: Theme.protein
        case .carbs: Theme.carbs
        case .fat: Theme.fat
        case .fiber: Theme.fiber
        }
    }
}

/// Petite étiquette (durée, statut).
struct Tag: View {
    let text: String
    var symbol: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: .capsule)
    }
}

/// Note du coach (ajustement appliqué, règle de sécurité).
struct CoachNote: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Image(systemName: "sparkles")
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.inner))
    }
}

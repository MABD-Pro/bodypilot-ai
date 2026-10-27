import SwiftUI

/// Carte principale : une question du jour, sa réponse, en verre.
struct CoachCard<Content: View>: View {
    let eyebrow: String
    let symbol: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Label {
                Text(eyebrow)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.8)
            } icon: {
                Image(systemName: symbol)
                    .font(.footnote.weight(.bold))
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

import SwiftUI

/// Bouton rond − / + des saisies de valeur (pesée, tour de taille, série) : maintenu, il répète.
struct StepButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 56
    var font: Font = .title2.weight(.bold)
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy, action)
        } label: {
            Image(systemName: symbol)
                .font(font)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }
}

/// Valeur réglable aux boutons − / + : VoiceOver la lit d'un bloc et la règle d'un balayage vertical.
struct SteppedValue<Value: View>: View {
    let accessibilityValue: String
    let decrease: () -> Void
    let increase: () -> Void
    @ViewBuilder let value: Value

    var body: some View {
        value
            .accessibilityElement(children: .combine)
            .accessibilityValue(accessibilityValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: withAnimation(.snappy, increase)
                case .decrement: withAnimation(.snappy, decrease)
                @unknown default: break
                }
            }
    }
}

extension View {
    /// Feuille à la hauteur prévue pour la taille de texte standard : elle grandit avec le texte,
    /// et passe en plein écran aux tailles d'accessibilité pour ne rien couper.
    func adaptiveDetents(height: CGFloat, alsoLarge: Bool = false) -> some View {
        modifier(AdaptiveDetents(height: height, alsoLarge: alsoLarge))
    }
}

private struct AdaptiveDetents: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let height: CGFloat
    let alsoLarge: Bool

    func body(content: Content) -> some View {
        content.presentationDetents(detents)
    }

    private var detents: Set<PresentationDetent> {
        if dynamicTypeSize.isAccessibilitySize { return [.large] }
        let fitted = PresentationDetent.height(height * scale)
        return alsoLarge ? [fitted, .large] : [fitted]
    }

    private var scale: CGFloat {
        switch dynamicTypeSize {
        case .xLarge: 1.08
        case .xxLarge: 1.16
        case .xxxLarge: 1.25
        default: 1
        }
    }
}

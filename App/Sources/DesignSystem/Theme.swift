import SwiftUI

/// Design system BodyPilot : une couleur par question du jour, espacements réguliers,
/// typographie arrondie, cartes en Liquid Glass sur un fond dégradé doux.
enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    enum Radius {
        static let card: CGFloat = 30
        static let inner: CGFloat = 18
    }

    /// « Que dois-je manger ? »
    static let nutrition = Color(red: 1.00, green: 0.45, blue: 0.32)
    /// « Quel entraînement ? »
    static let training = Color(red: 0.36, green: 0.45, blue: 1.00)
    /// « Est-ce que je progresse ? »
    static let progress = Color(red: 0.13, green: 0.76, blue: 0.60)

    static let protein = Color(red: 0.93, green: 0.33, blue: 0.45)
    static let carbs = Color(red: 1.00, green: 0.69, blue: 0.25)
    static let fat = Color(red: 0.55, green: 0.42, blue: 0.95)

    /// L'app est en français pour l'instant, quelle que soit la langue de l'appareil.
    static let locale = Locale(identifier: "fr_FR")

    static let springy = Animation.spring(response: 0.42, dampingFraction: 0.82)
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Fond dégradé maillé, discret, qui donne de la profondeur au verre.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.45], [0.6, 0.5], [1, 0.4],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: colorScheme == .dark ? darkColors : lightColors
        )
        .ignoresSafeArea()
    }

    private var lightColors: [Color] {
        [
            Color(red: 1.00, green: 0.88, blue: 0.82), Color(red: 1.00, green: 0.93, blue: 0.88), Color(red: 0.88, green: 0.90, blue: 1.00),
            Color(red: 0.98, green: 0.96, blue: 0.95), Color(red: 0.96, green: 0.96, blue: 0.99), Color(red: 0.90, green: 0.97, blue: 0.95),
            Color(red: 0.95, green: 0.95, blue: 0.98), Color(red: 0.93, green: 0.97, blue: 0.96), Color(red: 0.94, green: 0.94, blue: 0.99),
        ]
    }

    private var darkColors: [Color] {
        [
            Color(red: 0.30, green: 0.12, blue: 0.12), Color(red: 0.14, green: 0.10, blue: 0.20), Color(red: 0.10, green: 0.13, blue: 0.32),
            Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.07, green: 0.07, blue: 0.11), Color(red: 0.05, green: 0.17, blue: 0.17),
            Color(red: 0.04, green: 0.04, blue: 0.07), Color(red: 0.05, green: 0.06, blue: 0.09), Color(red: 0.05, green: 0.05, blue: 0.09),
        ]
    }
}

extension String {
    var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}

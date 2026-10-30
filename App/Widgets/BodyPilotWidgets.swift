import SwiftUI
import WidgetKit

@main
struct BodyPilotWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        WorkoutDoneControl()
        MealTakenControl()
        WorkoutActivityWidget()
    }
}

/// Couleurs de l'app, reprises ici : l'extension n'embarque pas le design system.
enum WidgetTheme {
    static let nutrition = Color(red: 1.00, green: 0.45, blue: 0.32)
    static let training = Color(red: 0.36, green: 0.45, blue: 1.00)
    static let progress = Color(red: 0.13, green: 0.76, blue: 0.60)
    static let protein = Color(red: 0.93, green: 0.33, blue: 0.45)
}

extension Int {
    /// « 1 240 » avec espace fine insécable, comme dans l'app.
    var frenchGrouped: String {
        let digits = String(abs(self))
        var grouped = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0 && index % 3 == 0 { grouped.append("\u{202F}") }
            grouped.append(character)
        }
        return (self < 0 ? "-" : "") + String(grouped.reversed())
    }
}

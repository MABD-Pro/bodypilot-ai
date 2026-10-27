import Foundation

public extension Double {
    /// Nombre à une décimale avec virgule (« 72,4 »), sans dépendre de la locale de l'appareil.
    var frenchOneDecimal: String {
        let rounded = (self * 10).rounded() / 10
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }

    /// Entier arrondi avec espace des milliers (« 2 150 »).
    var frenchInteger: String {
        let value = Int(self.rounded())
        let digits = String(abs(value))
        var grouped = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0 && index % 3 == 0 { grouped.append("\u{202F}") }
            grouped.append(character)
        }
        return (value < 0 ? "-" : "") + String(grouped.reversed())
    }
}

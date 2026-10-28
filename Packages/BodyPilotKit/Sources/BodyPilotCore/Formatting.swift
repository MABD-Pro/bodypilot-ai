import Foundation

public extension Double {
    /// Nombre à une décimale avec virgule (« 72,4 »), sans dépendre de la locale de l'appareil.
    /// Une valeur non calculable (NaN, infini) s'affiche « – » ; « -0,0 » devient « 0,0 ».
    var frenchOneDecimal: String {
        guard isFinite else { return "–" }
        // + 0 transforme le zéro négatif en zéro.
        let rounded = (self * 10).rounded() / 10 + 0
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }

    /// Variation signée à une décimale (« +0,3 », « -0,5 », « 0,0 ») : le signe suit la valeur affichée.
    var frenchSignedOneDecimal: String {
        guard isFinite else { return "–" }
        return ((self * 10).rounded() > 0 ? "+" : "") + frenchOneDecimal
    }

    /// Entier arrondi avec espace des milliers (« 2 150 »).
    var frenchInteger: String {
        guard isFinite else { return "–" }
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

public extension Double {
    /// Sans décimale inutile : « 80 », « 82,5 ».
    var frenchCompact: String {
        guard isFinite else { return "–" }
        let rounded = (self * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : rounded.frenchOneDecimal
    }
}

import BodyPilotCore
import Foundation

/// Un plat de la carte, estimé comme un repas décrit.
public struct MenuPick: Sendable, Equatable {
    public enum Fit: Sendable, Equatable {
        /// Protéines et calories dans les repères.
        case good
        /// Calories dans les repères, protéines justes.
        case lowProtein
        /// Plus copieux que les repères.
        case heavy
    }

    /// Ligne de la carte, telle que lue.
    public var dish: String
    public var meal: DescribedMeal
    public var fit: Fit
    public var score: Double
    /// Premier du classement.
    public var isBest = false

    public var macros: Macros { meal.macros }

    public var reason: String {
        switch fit {
        case .good: "Dans tes repères"
        case .lowProtein: isBest ? "Le plus riche en protéines de la carte, un peu sous tes repères" : "Protéines un peu justes pour ce repas"
        case .heavy: isBest ? "Le meilleur choix de la carte : laisse une partie des féculents ou de la sauce" : "Plus copieux que prévu : laisse une partie des féculents ou de la sauce"
        }
    }
}

/// Lit une carte de restaurant photographiée (texte reconnu sur l'iPhone) et classe les plats
/// selon les repères du repas : d'abord les protéines, puis les calories. Déterministe et local :
/// chaque plat passe par le même lecteur que « Décrire ».
public enum MenuAdvisor {
    /// Plats proposés au plus.
    public static let maxPicks = 3
    /// Au-delà de 110 % des calories du repas, le plat est jugé copieux (choix BodyPilot).
    static let heavyShare = 1.10
    /// Moins de 75 % des protéines visées : protéines justes.
    static let lowProteinShare = 0.75

    /// Rubriques qui ne sont pas des plats principaux : leurs lignes sont ignorées.
    static let skippedSections = ["dessert", "boisson", "vin", "biere", "cocktail", "aperitif", "digestif", "cafe", "soft", "sauce", "supplement", "accompagnement"]
    static let dishSections = ["entree", "plat", "formule", "menu", "suggestion", "specialite", "burger", "pizza", "salade", "pate", "viande", "poisson", "grillade", "carte", "bowl"]

    /// Lignes de la carte → noms de plats : prix retirés, rubriques et lignes de boissons ou
    /// de desserts écartées, une description en minuscules rattachée au plat d'au-dessus.
    public static func dishes(fromLines lines: [String]) -> [String] {
        var result: [String] = []
        var skipping = false
        for raw in lines {
            let line = withoutPrice(raw)
            let letters = line.filter(\.isLetter).count
            guard letters >= 3 else { continue }
            let key = MealTextParser.normalize(line)
            let words = key.split(separator: " ")
            // Rubrique : une ligne courte qui nomme une partie de la carte (« Nos desserts », « PLATS »).
            if words.count <= 3 {
                let named = words.contains { skippedSections.contains(String($0)) }
                let dishPart = words.contains { dishSections.contains(String($0)) }
                let hasFood = !MealTextParser.parse(line).foods.isEmpty
                if named, !hasFood || words.count == 1 { skipping = true; continue }
                if dishPart, words.count == 1 || !hasFood { skipping = false; continue }
                // Autre titre en capitales (« LA BRASSERIE ») : ignoré, sauf s'il nomme un plat du catalogue
                // (la table Ciqual reconnaît trop de mots pour en juger).
                if isHeading(line), MealTextParser.parseSegment(key).isEmpty { continue }
            }
            guard !skipping, line.count <= 90 else { continue }
            if let first = line.first, first.isLowercase, let last = result.popLast() {
                result.append(last + ", " + line)
            } else {
                result.append(line)
            }
        }
        return result
    }

    /// Plats classés, les mieux adaptés d'abord. `target` : les repères du repas au restaurant.
    public static func advise(lines: [String], target: Macros) -> [MenuPick] {
        var seen: Set<String> = []
        let picks = dishes(fromLines: lines).compactMap { dish -> MenuPick? in
            let parse = MealTextParser.parse(dish)
            guard !parse.foods.isEmpty, seen.insert(MealTextParser.normalize(dish)).inserted else { return nil }
            return pick(dish: dish, meal: DescribedMeal(text: dish, foods: parse.foods, dishName: dish), target: target)
        }
        var ranked = Array(picks.sorted { $0.score > $1.score }.prefix(maxPicks))
        if !ranked.isEmpty { ranked[0].isBest = true }
        return ranked
    }

    static func pick(dish: String, meal: DescribedMeal, target: Macros) -> MenuPick {
        let macros = meal.macros
        let proteinShare = target.proteinG > 0 ? macros.proteinG / target.proteinG : 1
        let kcalShare = target.kcal > 0 ? macros.kcal / target.kcal : 1
        let fit: MenuPick.Fit = kcalShare > heavyShare ? .heavy : proteinShare < lowProteinShare ? .lowProtein : .good
        // Protéines jusqu'à 100 % des repères, pénalité au-delà de 110 % des calories et sous 60 %.
        let score = min(proteinShare, 1) - 1.5 * max(0, kcalShare - heavyShare) - 0.5 * max(0, 0.6 - kcalShare)
        return MenuPick(dish: dish, meal: meal, fit: fit, score: score)
    }

    /// « Entrecôte grillée 24,50 € » → « Entrecôte grillée ».
    static func withoutPrice(_ line: String) -> String {
        var text = line.replacingOccurrences(of: #"\s*(€\s*)?\d+([.,]\d{1,2})?\s*(€|eur|euros)?\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: #"[.…·_-]{2,}"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—•*·")))
    }

    /// Ligne tout en capitales (« NOS PLATS »).
    static func isHeading(_ line: String) -> Bool {
        let letters = line.filter(\.isLetter)
        return letters.count >= 3 && letters.allSatisfy(\.isUppercase)
    }
}

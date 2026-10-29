import BodyPilotCore

/// Aliment de la table Ciqual, valeurs pour 100 g.
struct CiqualFood: Sendable {
    let code: String
    /// Nom complet (« Faisselle, 6% MG environ »).
    let name: String
    let per100g: Macros
    /// Fibres pour 100 g, quand Ciqual les a mesurées.
    let fibrePer100g: Double?
    /// Mots du nom, normalisés comme les phrases (`MealTextParser.normalize`).
    let words: [String]
    /// Mots de la tête du nom, avant la première virgule ou parenthèse (« faisselle »).
    let headWords: [String]

    /// Nom affiché : la tête seule, plus lisible (« Kiwi » plutôt que « Kiwi, chair sans peau, avec pépins, cru »).
    var shortName: String {
        let head = name.split(whereSeparator: { $0 == "," || $0 == "(" }).first.map(String.init) ?? name
        return head.trimmingCharacters(in: .whitespaces)
    }
}

/// Recherche d'un aliment dans la table Ciqual (ANSES, environ 3 300 aliments) : entre le catalogue
/// de plats et de portions (`FoodLexicon`) et le modèle embarqué. Hors ligne, gratuit, déterministe.
enum CiqualMatcher {
    static let foods: [CiqualFood] = CiqualTable.rows.split(separator: "\n").compactMap { line in
        let cells = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard cells.count >= 7, let kcal = Double(cells[2]) else { return nil }
        let name = cells[1]
        let head = name.split(whereSeparator: { $0 == "," || $0 == "(" }).first.map(String.init) ?? name
        return CiqualFood(
            code: cells[0],
            name: name,
            per100g: Macros(kcal: kcal, proteinG: Double(cells[3]) ?? 0, carbsG: Double(cells[4]) ?? 0, fatG: Double(cells[5]) ?? 0),
            fibrePer100g: Double(cells[6]),
            words: CiqualMatcher.words(of: name),
            headWords: CiqualMatcher.words(of: head)
        )
    }

    /// Mots vides des noms Ciqual, en plus de ceux des phrases.
    static let nameFillers: Set<String> = MealTextParser.fillers.union(["ou", "type", "san", "et"])
    /// Mots de quantité, retirés de la phrase avant la recherche.
    static let quantityWords: Set<String> = Set(FoodLexicon.units.keys)
        .union(MealTextParser.numberWords.keys)
        .union(MealTextParser.fractionWords.keys)
        .union(["g", "gr", "gramme", "kg", "kilo", "ml", "cl", "l", "litre"])
    /// Formes qu'on ne mange pas telles quelles (« lentille sèche », « à cuire ») : écartées sauf si demandées.
    static let rawForms: Set<String> = ["sec", "seche", "cuire", "deshydrate", "poudre", "lyophilise", "concentre"]
    /// Noms génériques préférés : la valeur moyenne vaut mieux qu'une variante.
    static let genericBonus: [String: Double] = ["moyen": 3, "nature": 2, "precision": 1]

    /// Poids d'une pièce, partie mangée (ordre de grandeur, choix BodyPilot) : Ciqual ne donne que 100 g.
    /// Clés : premier mot normalisé du nom Ciqual.
    static let pieceGrams: [String: Double] = [
        "mangue": 220, "kiwi": 75, "banane": 120, "pomme": 150, "poire": 150, "orange": 150, "clementine": 60,
        "mandarine": 60, "peche": 130, "nectarine": 130, "abricot": 40, "prune": 30, "figue": 50, "citron": 60,
        "pamplemousse": 250, "avocat": 150, "tomate": 120, "carotte": 80, "courgette": 200, "concombre": 300,
        "poivron": 150, "aubergine": 250, "oignon": 100, "kaki": 180, "grenade": 200,
    ]

    static func words(of text: String) -> [String] {
        MealTextParser.normalize(text).split(separator: " ").map(String.init)
    }

    /// Meilleur aliment pour un morceau de phrase normalisé, ou nil si aucun nom ne contient tous ses mots.
    /// Les tailles (« petit », « grand ») comptent d'abord comme mots du nom (« petit pois »),
    /// puis sont ignorées si rien ne correspond (« un petit kiwi »).
    static func food(for normalized: String) -> CiqualFood? {
        let words = normalized.split(separator: " ").map(String.init)
            .filter { !MealTextParser.fillers.contains($0) && !quantityWords.contains($0) && Double($0) == nil }
        if let found = best(for: words) { return found }
        let withoutSizes = words.filter { MealTextParser.sizeFactors[$0] == nil }
        return withoutSizes.count < words.count ? best(for: withoutSizes) : nil
    }

    private static func best(for keywords: [String]) -> CiqualFood? {
        guard let first = keywords.first else { return nil }
        let wanted = Set(keywords)
        var best: (score: Double, food: CiqualFood)?
        for food in foods {
            let words = Set(food.words)
            guard wanted.isSubset(of: words) else { continue }
            // Le moins de mots en trop possible, surtout dans la tête du nom (« pomme de terre » pour « pomme »).
            let extraHead = food.headWords.filter { !nameFillers.contains($0) && !wanted.contains($0) }.count
            let extraRest = food.words.dropFirst(food.headWords.count).filter { !nameFillers.contains($0) && !wanted.contains($0) }.count
            var score = 3 * Double(extraHead) + 0.5 * Double(extraRest)
            if food.words.first != first { score += 5 }
            for (word, bonus) in genericBonus where words.contains(word) { score -= bonus }
            if !rawForms.isDisjoint(with: words), rawForms.isDisjoint(with: wanted) { score += 4 }
            // Variantes allégées (« 0% MG ») seulement si elles sont demandées.
            if words.contains("mg"), !wanted.contains("mg") { score += words.contains("0") ? 3.5 : 2 }
            if let current = best, current.score < score || (current.score == score && current.food.name.count <= food.name.count) {
                continue
            }
            best = (score, food)
        }
        return best?.food
    }
}

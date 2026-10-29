import BodyPilotCore
import Foundation

/// Ce que le coach a compris d'un repas décrit en texte.
public struct MealParse: Sendable, Equatable {
    public var text: String
    public var foods: [DescribedFood]
    /// Morceaux de phrase sans aliment reconnu : à préciser, ou à confier au modèle embarqué.
    public var unrecognized: [String]

    public init(text: String, foods: [DescribedFood], unrecognized: [String] = []) {
        self.text = text
        self.foods = foods
        self.unrecognized = unrecognized
    }

    public var meal: DescribedMeal { DescribedMeal(text: text, foods: foods) }
    /// Questions de précision à poser : les portions devinées et les mots inconnus.
    public var needsClarification: Bool { !unrecognized.isEmpty || foods.contains(where: \.needsPortion) }
}

/// Lecture déterministe d'un repas décrit en français (« une grande assiette de pâtes carbo et un coca »).
///
/// Gratuit, hors ligne, instantané : catalogue d'aliments courants, quantités en grammes, en unités
/// (« 2 œufs ») ou en contenants (« un bol »), tailles (« petite », « grande »). Sans quantité,
/// la portion habituelle est proposée et marquée à confirmer.
public enum MealTextParser {
    /// Plus petit, normal, plus grand : les trois réponses possibles à « quelle quantité ? ».
    public static let portionChoices: [(label: String, factor: Double)] = [("Petite", 0.7), ("Normale", 1), ("Grande", 1.4)]

    static let sizeFactors: [String: Double] = [
        "petit": 0.7, "petite": 0.7, "grand": 1.4, "grande": 1.4, "gro": 1.4, "grosse": 1.4, "demi": 0.5, "moitie": 0.5,
    ]
    static let numberWords: [String: Double] = [
        "un": 1, "une": 1, "deu": 2, "troi": 3, "quatre": 4, "cinq": 5, "six": 6, "sept": 7, "huit": 8, "neuf": 9, "dix": 10,
        "onze": 11, "douze": 12, "quelque": 3,
    ]
    /// « un quart », « trois quarts », « un tiers » : multiplient le nombre qui les précède.
    static let fractionWords: [String: Double] = ["quart": 0.25, "tier": 1.0 / 3]
    /// Mots sans information, retirés avant de chercher un aliment inconnu.
    static let fillers: Set<String> = [
        "j", "ai", "mange", "pri", "bu", "avec", "de", "du", "d", "la", "le", "l", "les", "des", "au", "aux", "a", "en",
        "un", "une", "peu", "et", "puis", "ce", "midi", "soir", "matin", "c", "etait", "plu", "moin", "tres", "bien", "sur",
    ]

    private static let lexicon: [(alias: String, entry: LexiconEntry)] = FoodLexicon.entries
        .flatMap { entry in entry.aliases.map { (normalize($0), entry) } }
        .sorted { $0.alias.count > $1.alias.count }

    public static func parse(_ text: String) -> MealParse {
        var foods: [DescribedFood] = []
        var unrecognized: [String] = []
        for segment in segments(of: text) {
            var found = parseSegment(segment.normalized)
            // Absent du catalogue de plats : la table Ciqual, avant de signaler l'aliment inconnu.
            if found.isEmpty, let ciqual = CiqualMatcher.food(for: segment.normalized) {
                found = [food(ciqual, in: segment.normalized)]
            }
            if found.isEmpty {
                let meaningful = segment.normalized.split(separator: " ").filter { !fillers.contains(String($0)) && Double($0) == nil }
                if !meaningful.isEmpty { unrecognized.append(segment.original.trimmingCharacters(in: .whitespaces)) }
            }
            foods += found
        }
        return MealParse(text: text, foods: foods, unrecognized: unrecognized)
    }

    /// Liaisons qui séparent deux aliments, comparées une fois normalisées (« puis » → « pui »).
    static let linkWords: Set<String> = ["et", "avec", "pui", "plu"]

    /// Découpe sur la ponctuation et les liaisons (« et », « avec », « puis », « + »).
    /// Les nombres décimaux (« 1,5 l ») et les fractions (« 1/2 baguette ») sont lus avant :
    /// leur virgule ou leur barre ne sépare pas deux aliments.
    static func segments(of text: String) -> [(original: String, normalized: String)] {
        let separators = CharacterSet(charactersIn: ",;+\n/")
        return numbersRead(in: text).components(separatedBy: separators).flatMap { piece -> [(original: String, normalized: String)] in
            let words = piece.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            var parts: [[String]] = [[]]
            for word in words {
                if linkWords.contains(normalize(word)) {
                    parts.append([])
                } else {
                    parts[parts.count - 1].append(word)
                }
            }
            return parts.filter { !$0.isEmpty }.map { (original: $0.joined(separator: " "), normalized: normalize($0.joined(separator: " "))) }
        }.filter { !$0.normalized.isEmpty }
    }

    /// « 1,5 » → « 1.5 », « 1/2 » → « 0.5 », « un demi-litre » → « 0.5 litre ».
    static func numbersRead(in text: String) -> String {
        // « un demi-litre », « un demi kilo » : une quantité, pas une demi-portion.
        let halves = text.replacing(#/(?i)(une?\s+)?demi[- ]?(litre|kilo)/#) { "0.5 \($0.2)" }
        let decimals = halves.replacing(#/(\d),(\d)/#) { "\($0.1).\($0.2)" }
        return decimals.replacing(#/(\d+)\s?\/\s?(\d+)/#) { match in
            guard let numerator = Double(match.1), let denominator = Double(match.2), denominator > 0 else { return String(match.0) }
            let value = numerator / denominator
            return value == value.rounded() ? "\(Int(value))" : "\((value * 100).rounded() / 100)"
        }
    }

    /// Minuscules, sans accents ni pluriel : « Œufs brouillés » → « oeuf brouille ».
    static func normalize(_ text: String) -> String {
        let folded = text.lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
        let cleaned = String(folded.map { $0.isLetter || $0.isNumber || $0 == "." ? $0 : " " })
        return cleaned.split(separator: " ").map { word -> String in
            var word = String(word)
            if word.count > 3, let last = word.last, last == "s" || last == "x", Double(word) == nil { word.removeLast() }
            return word
        }.joined(separator: " ")
    }

    /// Aliments d'un morceau de phrase, du plus long nom au plus court, sans chevauchement.
    static func parseSegment(_ segment: String) -> [DescribedFood] {
        let padded = " \(segment) "
        var taken: [Range<String.Index>] = []
        var matches: [(range: Range<String.Index>, entry: LexiconEntry)] = []
        for (alias, entry) in lexicon {
            var searchStart = padded.startIndex
            while let spaced = padded.range(of: " \(alias) ", range: searchStart..<padded.endIndex) {
                // Le nom seul, sans ses espaces : deux aliments voisins (« steak frites ») partagent
                // l'espace qui les sépare sans se chevaucher.
                let range = padded.index(after: spaced.lowerBound)..<padded.index(before: spaced.upperBound)
                if !taken.contains(where: { $0.overlaps(range) }) {
                    taken.append(range)
                    matches.append((range, entry))
                }
                searchStart = range.upperBound
            }
        }
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }

        var previousEnd = padded.startIndex
        return matches.enumerated().map { index, match in
            // La quantité se lit juste avant l'aliment (« deux œufs ») ; les grammes partout (« riz 200 g »).
            let before = String(padded[previousEnd..<match.range.lowerBound])
            let after = index == matches.count - 1 ? String(padded[match.range.upperBound...]) : ""
            previousEnd = match.range.upperBound
            return food(match.entry, before: before, after: after)
        }
    }

    static func food(_ entry: LexiconEntry, before: String, after: String) -> DescribedFood {
        let words = before.split(separator: " ").map(String.init)
        if let explicit = explicitQuantity(in: before + " " + after) {
            return described(entry, grams: explicit.grams, label: explicit.label)
        }
        var count = quantity(in: words)
        var size = words.compactMap { sizeFactors[$0] }.last
        // « une demi-baguette » : la moitié d'une baguette, pas « 1 demi-baguette ».
        if size == 0.5, count == nil || count == 1 {
            count = 0.5
            size = nil
        }
        let unit = words.last { FoodLexicon.units[$0] != nil || entry.unitOverrides[$0] != nil }

        var grams: Double
        var label: String
        let quantity = count ?? 1
        if let unit {
            let unitGrams = entry.unitOverrides[unit] ?? FoodLexicon.units[unit].flatMap { $0 > 0 ? $0 : nil }
                ?? entry.food.unit?.grams ?? entry.portionGrams
            grams = unitGrams * quantity
            let name = unitNames[unit] ?? (singular: unit, plural: unit + "s", masculine: false)
            label = "\(format(quantity)) \(adjective(size, masculine: name.masculine, plural: quantity > 1))\(quantity > 1 ? name.plural : name.singular)"
        } else if let count, let foodUnit = entry.food.unit {
            grams = foodUnit.grams * count
            let masculine = masculineFoodUnits.contains(foodUnit.singular)
            label = "\(format(count)) \(adjective(size, masculine: masculine, plural: count > 1))\(count > 1 ? foodUnit.plural : foodUnit.singular)"
        } else {
            grams = entry.portionGrams * quantity
            label = quantity > 1 ? "\(format(quantity)) portions" : entry.portionLabel
            if size != nil { label = "\(adjective(size, masculine: false, plural: false))portion".capitalizedFirst }
        }
        grams *= size ?? 1
        // Ni quantité, ni contenant, ni taille : la portion habituelle est une supposition.
        let isVague = unit == nil && size == nil && count == nil
        return described(entry, grams: grams, label: label, needsPortion: isVague)
    }

    /// Aliment Ciqual : grammes écrits, sinon contenant (« un bol »), sinon 100 g par pièce, à confirmer.
    /// Ciqual ne donne pas de portion : sans quantité ni contenant, le coach demande « Quelle quantité ? ».
    static func food(_ ciqual: CiqualFood, in segment: String) -> DescribedFood {
        let words = segment.split(separator: " ").map(String.init)
        var grams: Double
        var label: String
        var needsPortion = false
        if let explicit = explicitQuantity(in: segment) {
            grams = explicit.grams
            label = explicit.label
        } else {
            let count = quantity(in: words) ?? 1
            if let unit = words.last(where: { (FoodLexicon.units[$0] ?? 0) > 0 }), let unitGrams = FoodLexicon.units[unit] {
                grams = unitGrams * count
                let name = unitNames[unit] ?? (singular: unit, plural: unit + "s", masculine: false)
                label = "\(format(count)) \(count > 1 ? name.plural : name.singular)"
            } else {
                grams = 100 * count
                label = "≈ \(Int(grams.rounded())) g"
                needsPortion = true
            }
        }
        return DescribedFood(name: ciqual.shortName, grams: grams, quantityLabel: label, macros: ciqual.per100g.scaled(by: grams / 100), needsPortion: needsPortion)
    }

    /// Dernier nombre avant l'aliment ; une fraction multiplie le nombre qui la précède
    /// (« trois quarts » = 0,75, « un tiers » = 0,33).
    static func quantity(in words: [String]) -> Double? {
        var last: Double?
        var previous: Double?
        for word in words {
            if let fraction = fractionWords[word] {
                last = (previous ?? 1) * fraction
                previous = nil
            } else if let number = Double(word) ?? numberWords[word] {
                last = number
                previous = number
            }
        }
        return last
    }

    static let unitNames: [String: (singular: String, plural: String, masculine: Bool)] = [
        "assiette": ("assiette", "assiettes", false), "bol": ("bol", "bols", true), "verre": ("verre", "verres", true),
        "tasse": ("tasse", "tasses", false), "part": ("part", "parts", false), "tranche": ("tranche", "tranches", false),
        "cuillere": ("cuillère", "cuillères", false), "poignee": ("poignée", "poignées", false), "canette": ("canette", "canettes", false),
        "bouteille": ("bouteille", "bouteilles", false), "morceau": ("morceau", "morceaux", true), "carre": ("carré", "carrés", true),
        "barquette": ("barquette", "barquettes", false), "pot": ("pot", "pots", true), "boite": ("boîte", "boîtes", false),
        "dose": ("dose", "doses", false), "portion": ("portion", "portions", false), "piece": ("pièce", "pièces", false),
        "baguette": ("baguette", "baguettes", false), "pinte": ("pinte", "pintes", false),
    ]
    static let masculineFoodUnits: Set<String> = [
        "œuf", "burger", "kebab", "sandwich", "croissant", "croque", "yaourt", "fruit", "café", "sucre", "pain au chocolat",
    ]

    /// « petite », « grands », « demi- » : accordé au contenant.
    private static func adjective(_ factor: Double?, masculine: Bool, plural: Bool) -> String {
        let base: String
        switch factor {
        case 0.7: base = masculine ? "petit" : "petite"
        case 1.4: base = masculine ? "grand" : "grande"
        case 0.5: return "demi-"
        default: return ""
        }
        return base + (plural ? "s " : " ")
    }

    private static func described(_ entry: LexiconEntry, grams: Double, label: String, needsPortion: Bool = false) -> DescribedFood {
        DescribedFood(name: entry.food.name, grams: grams, quantityLabel: label, macros: entry.food.per100g.scaled(by: grams / 100), needsPortion: needsPortion)
    }

    /// « 200 g », « 33 cl », « 1,5 l » : en grammes (1 ml ≈ 1 g), et telle que l'utilisateur l'a dite.
    static func explicitQuantity(in text: String) -> (grams: Double, label: String)? {
        let words = text.split(separator: " ").map(String.init)
        for (index, word) in words.enumerated() {
            // « 200g » collé ou « 200 g » séparé.
            let digits = word.prefix { $0.isNumber || $0 == "." }
            let suffix = String(word.dropFirst(digits.count))
            guard let value = Double(digits), value > 0 else { continue }
            let unit = suffix.isEmpty ? (index + 1 < words.count ? words[index + 1] : "") : suffix
            let written = format(value)
            switch unit {
            case "g", "gr", "gramme": return (value, "\(Int(value.rounded())) g")
            case "kg", "kilo": return (value * 1000, "\(written) kg")
            case "ml": return (value, "\(written) ml")
            case "cl": return (value * 10, "\(written) cl")
            case "l", "litre": return (value * 1000, "\(written) l")
            default: continue
            }
        }
        return nil
    }

    /// « 2 », « ½ », « ¾ », « 1,5 ».
    private static func format(_ count: Double) -> String {
        if count == count.rounded() { return "\(Int(count))" }
        let fractions: [(Double, String)] = [(0.25, "¼"), (1.0 / 3, "⅓"), (0.5, "½"), (2.0 / 3, "⅔"), (0.75, "¾")]
        if let fraction = fractions.first(where: { abs($0.0 - count) < 0.01 }) { return fraction.1 }
        return count.frenchOneDecimal
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

import BodyPilotCore
import Foundation

/// Produit emballé lu par son code-barres (Open Food Facts), valeurs pour 100 g.
public struct PackagedFood: Sendable, Equatable, Codable {
    public var barcode: String
    public var name: String
    public var brand: String?
    public var per100g: Macros
    /// Portion indiquée sur l'emballage, en grammes.
    public var servingGrams: Double?
    /// Nutri-Score (a à e), quand il est connu.
    public var nutriScore: String?

    public init(barcode: String, name: String, brand: String? = nil, per100g: Macros, servingGrams: Double? = nil, nutriScore: String? = nil) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.per100g = per100g
        self.servingGrams = servingGrams
        self.nutriScore = nutriScore
    }

    /// Protéines pour 100 kcal : l'indicateur clé en recomposition.
    public var proteinPer100kcal: Double {
        per100g.kcal > 0 ? per100g.proteinG / per100g.kcal * 100 : 0
    }

    /// Lecture de la réponse de l'API Open Food Facts (`/api/v2/product/{code}.json`).
    /// `nil` si le produit est inconnu ou sans calories.
    public static func fromOpenFoodFacts(_ data: Data, barcode: String) -> PackagedFood? {
        struct Response: Decodable {
            let status: Int?
            let product: Product?
        }
        struct Product: Decodable {
            let product_name_fr: String?
            let product_name: String?
            let brands: String?
            let serving_quantity: FlexibleDouble?
            let serving_size: String?
            let nutriscore_grade: String?
            let nutrition_grades: String?
            let nutriments: [String: FlexibleDouble]?
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              response.status != 0, let product = response.product,
              let nutriments = product.nutriments else { return nil }
        func value(_ key: String) -> Double? { nutriments[key]?.value }
        // Calories : en kcal si présentes, sinon converties depuis les kJ.
        guard let kcal = value("energy-kcal_100g") ?? value("energy_100g").map({ $0 / 4.184 }), kcal > 0 else { return nil }
        let name = [product.product_name_fr, product.product_name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Produit \(barcode)"
        let brand = product.brands?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        // Le Nutri-Score est rangé sous deux noms selon l'âge de la fiche.
        let grade = [product.nutriscore_grade, product.nutrition_grades]
            .compactMap { $0?.lowercased() }
            .first { ["a", "b", "c", "d", "e"].contains($0) }
        // Portion : chiffrée si possible, sinon lue dans le texte (« 15 g »).
        let serving = product.serving_quantity?.value ?? product.serving_size.flatMap(gramsInServing)
        // La marque n'apporte rien quand elle répète le nom (« Nutella »).
        let shownBrand = brand.flatMap { $0.isEmpty || $0.caseInsensitiveCompare(name) == .orderedSame ? nil : $0 }
        return PackagedFood(
            barcode: barcode,
            name: name,
            brand: shownBrand,
            per100g: Macros(kcal: kcal, proteinG: value("proteins_100g") ?? 0, carbsG: value("carbohydrates_100g") ?? 0, fatG: value("fat_100g") ?? 0, fiberG: value("fiber_100g") ?? 0),
            servingGrams: serving.flatMap { $0 > 0 ? $0 : nil },
            nutriScore: grade
        )
    }

    /// Grammes d'une portion écrite en texte : « 15 g », « 1 pot (125 g) », « 30g ».
    static func gramsInServing(_ text: String) -> Double? {
        let lowered = text.lowercased().replacingOccurrences(of: ",", with: ".")
        guard let range = lowered.range(of: #"(\d+(\.\d+)?)\s*g\b"#, options: .regularExpression) else { return nil }
        let number = lowered[range].filter { $0.isNumber || $0 == "." }
        return Double(number)
    }
}

/// Nombre que l'API rend tantôt en nombre, tantôt en texte (« 12.5 »).
struct FlexibleDouble: Decodable, Sendable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            value = number
        } else if let text = try? container.decode(String.self) {
            value = Double(text.replacingOccurrences(of: ",", with: "."))
        } else {
            value = nil
        }
    }
}

/// Avis du coach sur un produit scanné en rayon, pour un objectif de recomposition.
public struct ProductVerdict: Sendable, Equatable {
    public enum Rating: Sendable, Equatable {
        /// Riche en protéines pour ses calories.
        case great
        /// Correct, sans plus.
        case fine
        /// Beaucoup de calories pour peu de protéines : à garder occasionnel.
        case occasional
    }

    public var rating: Rating
    public var headline: String
    public var detail: String

    /// Seuils (choix BodyPilot) : 10 g de protéines pour 100 kcal ou plus = excellent ; une densité
    /// de plus de 400 kcal pour 100 g avec moins de 5 g de protéines pour 100 kcal = occasionnel.
    public static func of(_ food: PackagedFood) -> ProductVerdict {
        let density = food.proteinPer100kcal
        let kcal = food.per100g.kcal
        let densityText = "\(density.frenchOneDecimal)\u{00A0}g de protéines pour 100\u{00A0}kcal"
        if density >= 10 {
            return ProductVerdict(rating: .great, headline: "Très bon choix pour tes protéines", detail: "\(densityText) : il aide à atteindre ton objectif sans trop de calories.")
        }
        if kcal >= 400 && density < 5 {
            return ProductVerdict(rating: .occasional, headline: "À garder pour le plaisir", detail: "\(kcal.frenchInteger)\u{00A0}kcal pour 100\u{00A0}g et \(densityText) : très calorique pour ce qu'il apporte.")
        }
        if density >= 5 {
            return ProductVerdict(rating: .fine, headline: "Correct", detail: "\(densityText) : une source d'appoint, à associer à une vraie portion de protéines.")
        }
        return ProductVerdict(rating: .fine, headline: "Peu de protéines", detail: "\(densityText) : il ne t'aide pas pour les protéines, mais reste raisonnable en calories (\(kcal.frenchInteger)\u{00A0}kcal pour 100\u{00A0}g).")
    }
}

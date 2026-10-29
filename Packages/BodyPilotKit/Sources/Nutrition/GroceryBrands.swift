import Foundation

/// Marque conseillée pour un article de la liste de courses, tirée d'Open Food Facts.
public struct GroceryBrandPick: Sendable, Equatable, Identifiable {
    public var id: String { barcode }
    public var brand: String
    public var product: String
    /// Nutri-Score (« A » à « E »), quand Open Food Facts le connaît.
    public var nutriScore: String?
    /// Groupe NOVA de transformation (1 : brut, 4 : ultra-transformé).
    public var nova: Int?
    public var barcode: String

    public init(brand: String, product: String, nutriScore: String?, nova: Int?, barcode: String) {
        self.brand = brand
        self.product = product
        self.nutriScore = nutriScore
        self.nova = nova
        self.barcode = barcode
    }

    /// Fiche du produit sur Open Food Facts.
    public var url: URL? { URL(string: "https://fr.openfoodfacts.org/produit/\(barcode)") }
}

/// Recherche d'un article dans Open Food Facts et règles pour garder les bons produits.
public struct GroceryBrandQuery: Sendable, Equatable {
    public var terms: String
    /// Mots tous présents dans le nom du produit (normalisés, au début d'un mot).
    public var must: [String]
    /// Mots qui écartent un produit (« fraise » pour un skyr nature).
    public var exclude: [String]
    /// Le nom doit commencer par l'une de ces phrases (« feta » écarte « Lentilles boulgour féta »).
    public var lead: [String]
    /// Lipides maximum pour 100 g (produits 0 %).
    public var maxFat: Double?
    /// Source de protéines : les plus riches passent devant.
    public var isProteinSource: Bool

    public init(terms: String, must: [String], exclude: [String] = [], lead: [String] = [], maxFat: Double? = nil, isProteinSource: Bool = false) {
        self.terms = terms
        self.must = must
        self.exclude = exclude
        self.lead = lead
        self.maxFat = maxFat
        self.isProteinSource = isProteinSource
    }
}

struct GroceryBrandEntry: Sendable {
    let query: GroceryBrandQuery
    let picks: [GroceryBrandPick]
}

/// Produit tel que le renvoie la recherche d'Open Food Facts (champs utiles seulement).
public struct OpenFoodFactsProduct: Sendable, Decodable, Equatable {
    public var code: String?
    public var name: String?
    public var brands: String?
    public var nutriScore: String?
    public var nova: Int?
    public var scans: Double?
    public var proteinPer100g: Double?
    public var fatPer100g: Double?
    /// Pays de vente (« en:france »), quand la réponse les donne.
    public var countries: [String]?

    public init(code: String?, name: String?, brands: String?, nutriScore: String? = nil, nova: Int? = nil, scans: Double? = nil, proteinPer100g: Double? = nil, fatPer100g: Double? = nil, countries: [String]? = nil) {
        self.code = code
        self.name = name
        self.brands = brands
        self.nutriScore = nutriScore
        self.nova = nova
        self.scans = scans
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.countries = countries
    }

    private enum Keys: String, CodingKey {
        case code, brands, nutriments
        case productName = "product_name", productNameFr = "product_name_fr"
        case nutriScore = "nutriscore_grade", nova = "nova_group", scans = "unique_scans_n", countries = "countries_tags"
    }

    private enum NutrimentKeys: String, CodingKey {
        case protein = "proteins_100g", fat = "fat_100g"
    }

    /// Open Food Facts écrit parfois les nombres en texte : on accepte les deux.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        code = Self.text(container, .code)
        let french = Self.text(container, .productNameFr)
        name = french?.isEmpty == false ? french : Self.text(container, .productName)
        brands = Self.text(container, .brands)
        nutriScore = Self.text(container, .nutriScore)
        nova = Self.number(container, .nova).map { Int($0) }
        scans = Self.number(container, .scans)
        countries = try? container.decodeIfPresent([String].self, forKey: .countries)
        if let nutriments = try? container.nestedContainer(keyedBy: NutrimentKeys.self, forKey: .nutriments) {
            proteinPer100g = Self.number(nutriments, .protein)
            fatPer100g = Self.number(nutriments, .fat)
        }
    }

    private static func text<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return String(Int(value)) }
        return nil
    }

    private static func number<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) { return Double(value.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    /// Première marque citée, sous son nom usuel (« BJORG ET CIE, Bjorg » → « Bjorg ») ; nil si écartée.
    var mainBrand: String? {
        guard let first = brands?.split(separator: ",").first?.trimmingCharacters(in: .whitespaces), !first.isEmpty else { return nil }
        let brand = GroceryBrandTable.brandAliases[GroceryBrands.normalize(first)] ?? first
        return brand.isEmpty ? nil : brand
    }
}

/// Marques conseillées : une sélection embarquée (générée par scripts/openfoodfacts) et la même
/// recherche en direct, quand l'utilisateur la demande. Les règles sont celles du script : les deux
/// doivent rester identiques.
public enum GroceryBrands {
    static let grades: [String: Int] = ["a": 0, "b": 1, "c": 2, "d": 3, "e": 4]
    /// Marques gardées par article dans la sélection embarquée.
    public static let embeddedPicks = 2

    /// Sélection embarquée pour un article (nom affiché dans la liste), vide pour les produits frais.
    public static func picks(for itemName: String) -> [GroceryBrandPick] {
        GroceryBrandTable.entries[itemName]?.picks ?? []
    }

    /// Recherche de l'article, s'il a une marque à conseiller.
    public static func query(for itemName: String) -> GroceryBrandQuery? {
        GroceryBrandTable.entries[itemName]?.query
    }

    static let searchFields = "code,product_name,product_name_fr,brands,nutriscore_grade,nova_group,unique_scans_n,nutriments,countries_tags"

    /// Adresse de la recherche Open Food Facts : produits vendus en France, les plus scannés d'abord.
    public static func searchURL(for query: GroceryBrandQuery) -> URL? {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        components?.queryItems = [
            ("search_terms", query.terms), ("search_simple", "1"), ("action", "process"), ("json", "1"),
            ("tagtype_0", "countries"), ("tag_contains_0", "contains"), ("tag_0", "france"),
            ("sort_by", "unique_scans_n"), ("page_size", "100"), ("fields", searchFields),
        ].map { URLQueryItem(name: $0.0, value: $0.1) }
        return components?.url
    }

    /// Réponse de la recherche, rangée : les meilleurs produits, une seule fois par marque.
    public static func picks(fromSearchResponse data: Data, for query: GroceryBrandQuery, count: Int = 5) throws -> [GroceryBrandPick] {
        struct Response: Decodable { let products: [OpenFoodFactsProduct] }
        return rank(try JSONDecoder().decode(Response.self, from: data).products, for: query, count: count)
    }

    /// Produits retenus, du meilleur au moins bon : Nutri-Score d'abord, puis NOVA, protéines pour
    /// les sources de protéines, popularité. Une marque n'apparaît qu'une fois.
    public static func rank(_ products: [OpenFoodFactsProduct], for query: GroceryBrandQuery, count: Int) -> [GroceryBrandPick] {
        let ranked = products.filter { isEligible($0, for: query) }
            .map { (product: $0, score: score($0, for: query)) }
            // Tri stable, comme celui du script.
            .enumerated().sorted { ($0.element.score, $0.offset) < ($1.element.score, $1.offset) }
            .map(\.element.product)
        var picks: [GroceryBrandPick] = []
        var brands: [String] = []
        for product in ranked {
            guard let brand = product.mainBrand, let name = product.name, let code = product.code else { continue }
            // « Barilla » et « BARILLA NORGE AS » sont la même marque.
            let key = normalize(brand)
            guard !brands.contains(where: { key.hasPrefix($0) || $0.hasPrefix(key) }) else { continue }
            brands.append(key)
            let grade = product.nutriScore?.lowercased()
            picks.append(GroceryBrandPick(
                brand: brand,
                product: name.trimmingCharacters(in: .whitespaces),
                nutriScore: grade.flatMap { grades[$0] != nil ? $0.uppercased() : nil },
                nova: product.nova,
                barcode: code
            ))
            if picks.count == count { break }
        }
        return picks
    }

    static func isEligible(_ product: OpenFoodFactsProduct, for query: GroceryBrandQuery) -> Bool {
        guard let name = product.name, !name.isEmpty, product.mainBrand != nil, product.code?.isEmpty == false else { return false }
        if let countries = product.countries, !countries.isEmpty, !countries.contains("en:france") { return false }
        let words = normalize(name).split(separator: " ").map(String.init)
        guard query.lead.isEmpty || query.lead.contains(where: { starts(words, normalize($0)) }) else { return false }
        guard query.must.allSatisfy({ contains(words, normalize($0)) }),
              !query.exclude.contains(where: { contains(words, normalize($0)) })
        else { return false }
        if let maxFat = query.maxFat {
            guard let fat = product.fatPer100g, fat <= maxFat else { return false }
        }
        return true
    }

    /// Plus petit = meilleur.
    static func score(_ product: OpenFoodFactsProduct, for query: GroceryBrandQuery) -> Double {
        let grade = product.nutriScore.flatMap { grades[$0.lowercased()] } ?? 5
        var value = Double(grade * 3 + ((product.nova ?? 4) - 1) * 2)
        if query.isProteinSource { value -= (product.proteinPer100g ?? 0) / 10 }
        value -= log10((product.scans ?? 0) + 1) / 2
        return value
    }

    /// Minuscules, sans accents, ponctuation remplacée par des espaces.
    static func normalize(_ text: String) -> String {
        let folded = text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        let spaced = String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return spaced.split(separator: " ").joined(separator: " ")
    }

    /// Le nom commence par la phrase (« Feta AOP » pour feta, pas « Lentilles boulgour féta »).
    static func starts(_ nameWords: [String], _ phrase: String) -> Bool {
        let words = phrase.split(separator: " ").map(String.init)
        return !words.isEmpty && nameWords.count >= words.count && words.indices.allSatisfy { nameWords[$0].hasPrefix(words[$0]) }
    }

    /// Les mots de la phrase se suivent dans le nom, chacun au début d'un mot (« lentille » → « lentilles »).
    static func contains(_ nameWords: [String], _ phrase: String) -> Bool {
        let words = phrase.split(separator: " ").map(String.init)
        guard !words.isEmpty, nameWords.count >= words.count else { return false }
        for start in 0...(nameWords.count - words.count)
        where words.indices.allSatisfy({ nameWords[start + $0].hasPrefix(words[$0]) }) {
            return true
        }
        return false
    }
}

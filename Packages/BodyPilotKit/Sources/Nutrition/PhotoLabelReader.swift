/// Étiquettes d'un classifieur d'images (Vision, en anglais) → phrase française que le lecteur de repas comprend.
///
/// Sert de secours quand le modèle embarqué ne lit pas les images : la phrase préremplit
/// la saisie « Décrire », l'utilisateur la corrige, puis le coach demande les portions.
public enum PhotoLabelReader {
    /// En dessous, l'étiquette est trop incertaine pour être proposée.
    static let minimumConfidence = 0.3
    static let maximumFoods = 4

    /// Identifiants Vision → nom compris par `MealTextParser`. Les plus précis d'abord.
    static let names: [String: String] = [
        "pizza": "pizza", "pasta": "pâtes", "spaghetti": "pâtes", "salad": "salade composée", "rice": "riz",
        "soup": "soupe", "steak": "steak", "poultry": "poulet", "meat": "viande", "meatball": "boulettes de viande",
        "beef": "bœuf", "ham": "jambon", "bacon": "jambon", "sausage": "saucisse", "fish": "poisson",
        "salmon": "saumon", "tuna": "thon", "seafood": "poisson", "sushi": "sushis", "hamburger": "burger",
        "sandwich": "sandwich", "taco": "tacos", "burrito": "wrap", "kebab": "kebab", "hummus": "houmous",
        "curry": "riz", "paella": "riz", "risotto": "riz", "ramen": "soupe", "omelet": "omelette", "egg": "œufs",
        "fries": "frites", "potato": "pommes de terre", "bread": "pain", "bagel": "bagel", "croissant": "croissant",
        "crepe": "gâteau", "pancake": "gâteau", "waffle": "gâteau", "muffin": "gâteau", "cake": "gâteau",
        "cheesecake": "gâteau", "cupcake": "gâteau", "cookie": "biscuits", "donut": "gâteau", "pie": "gâteau",
        "pastry": "viennoiserie", "ice_cream": "glace", "chocolate": "chocolat", "cereal": "céréales",
        "yogurt": "yaourt", "cheese": "fromage", "fruit": "fruit", "apple": "pomme", "banana": "banane",
        "grape": "raisin", "melon": "fruit", "strawberry": "fraises", "oranges": "orange", "avocado": "avocat",
        "vegetable": "légumes", "broccoli": "brocoli", "carrot": "carottes", "tomato": "tomates",
        "cucumber": "légumes", "lettuce": "salade", "mushroom": "légumes", "bean": "haricots", "nut": "noix",
        "almond": "amandes", "coffee": "café", "tea_drink": "thé", "juice": "jus", "smoothie": "jus",
        "milkshake": "lait", "soda": "soda", "beer": "bière", "wine": "vin",
    ]

    /// Phrase à proposer (« pizza, salade composée »), ou `nil` si aucun aliment n'est reconnu avec assez de confiance.
    public static func sentence(from labels: [(identifier: String, confidence: Double)]) -> String? {
        var seen: Set<String> = []
        let foods = labels
            .filter { $0.confidence >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }
            .compactMap { names[$0.identifier] }
            .filter { seen.insert($0).inserted }
            .prefix(maximumFoods)
        return foods.isEmpty ? nil : foods.joined(separator: ", ")
    }
}

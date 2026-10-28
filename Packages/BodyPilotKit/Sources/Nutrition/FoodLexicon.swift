import BodyPilotCore

/// Aliment reconnaissable dans une phrase, avec sa portion habituelle.
///
/// Valeurs moyennes arrondies (ordre de grandeur Ciqual) : une estimation honnête, pas une pesée.
struct LexiconEntry: Sendable {
    let food: Food
    /// Mots qui le désignent, sans accents ni pluriel (voir `MealTextParser.normalize`).
    let aliases: [String]
    /// Portion par défaut quand aucune quantité n'est donnée.
    let portionGrams: Double
    let portionLabel: String
    /// Contenants dont le poids diffère pour cet aliment (« un verre de vin » = 125 ml).
    let unitOverrides: [String: Double]

    init(_ food: Food, _ aliases: [String], portion: Double, _ portionLabel: String = "1 portion", units: [String: Double] = [:]) {
        self.food = food
        self.aliases = aliases
        self.portionGrams = portion
        self.portionLabel = portionLabel
        self.unitOverrides = units
    }
}

enum FoodLexicon {
    /// Contenants et mesures courantes, en grammes (1 ml ≈ 1 g).
    static let units: [String: Double] = [
        "assiette": 300, "bol": 300, "verre": 200, "tasse": 150, "part": 150, "tranche": 35,
        "cuillere": 15, "poignee": 30, "canette": 330, "bouteille": 500, "morceau": 30,
        "carre": 10, "barquette": 250, "pot": 125, "boite": 140, "dose": 30, "portion": 0, "piece": 0,
    ]

    static let entries: [LexiconEntry] = [
        // Plats
        LexiconEntry(Food("Pâtes carbonara", kcal: 180, protein: 7, carbs: 20, fat: 8), ["pate carbonara", "pate carbo", "carbonara", "carbo"], portion: 350, "1 assiette"),
        LexiconEntry(Food("Pâtes bolognaise", kcal: 150, protein: 7, carbs: 19, fat: 5), ["pate bolognaise", "pate bolo", "bolognaise", "spaghetti bolognaise"], portion: 350, "1 assiette"),
        LexiconEntry(Food("Pâtes", kcal: 131, protein: 5, carbs: 25, fat: 1.1), ["pate", "spaghetti", "penne", "tagliatelle", "coquillette"], portion: 250, "1 assiette"),
        LexiconEntry(Food("Riz", kcal: 130, protein: 2.7, carbs: 28, fat: 0.3), ["riz"], portion: 200, "1 assiette"),
        LexiconEntry(Food("Pizza", kcal: 260, protein: 11, carbs: 30, fat: 10, unit: FoodUnit(grams: 350, singular: "pizza", plural: "pizzas")), ["pizza", "pizza 4 fromage", "pizza quatre fromage", "pizza fromage"], portion: 350, "1 pizza", units: ["part": 120]),
        LexiconEntry(Food("Burger", kcal: 250, protein: 13, carbs: 24, fat: 11, unit: FoodUnit(grams: 220, singular: "burger", plural: "burgers")), ["burger", "hamburger", "cheeseburger"], portion: 220, "1 burger"),
        LexiconEntry(Food("Frites", kcal: 300, protein: 3.4, carbs: 38, fat: 15), ["frite"], portion: 150, "1 portion"),
        LexiconEntry(Food("Kebab", kcal: 220, protein: 12, carbs: 20, fat: 10, unit: FoodUnit(grams: 400, singular: "kebab", plural: "kebabs")), ["kebab", "tacos", "durum"], portion: 400, "1 kebab"),
        LexiconEntry(Food("Sandwich jambon-beurre", kcal: 260, protein: 12, carbs: 30, fat: 10, unit: FoodUnit(grams: 250, singular: "sandwich", plural: "sandwichs")), ["jambon beurre", "sandwich jambon"], portion: 250, "1 sandwich"),
        LexiconEntry(Food("Sandwich", kcal: 240, protein: 11, carbs: 28, fat: 9, unit: FoodUnit(grams: 250, singular: "sandwich", plural: "sandwichs")), ["sandwich", "panini", "wrap", "bagel"], portion: 250, "1 sandwich"),
        LexiconEntry(Food("Croque-monsieur", kcal: 250, protein: 14, carbs: 20, fat: 13, unit: FoodUnit(grams: 180, singular: "croque", plural: "croques")), ["croque monsieur", "croque"], portion: 180, "1 croque"),
        LexiconEntry(Food("Quiche", kcal: 270, protein: 9, carbs: 18, fat: 18), ["quiche", "tarte salee"], portion: 150, "1 part"),
        LexiconEntry(Food("Salade composée", kcal: 120, protein: 6, carbs: 8, fat: 7), ["salade composee", "salade cesar", "salade nicoise", "poke", "poke bowl"], portion: 300, "1 assiette"),
        LexiconEntry(Food("Couscous", kcal: 150, protein: 8, carbs: 17, fat: 5), ["couscou"], portion: 400, "1 assiette"),
        LexiconEntry(Food("Sushis", kcal: 150, protein: 6, carbs: 28, fat: 1.5, unit: FoodUnit(grams: 30, singular: "pièce", plural: "pièces")), ["sushi", "maki", "california", "sashimi"], portion: 240, "8 pièces"),
        LexiconEntry(Food("Omelette", kcal: 155, protein: 11, carbs: 1, fat: 12), ["omelette"], portion: 150, "1 omelette"),
        LexiconEntry(Food("Soupe", kcal: 40, protein: 1.5, carbs: 6, fat: 1), ["soupe", "veloute", "potage"], portion: 300, "1 bol"),
        LexiconEntry(Food("Purée", kcal: 100, protein: 2, carbs: 14, fat: 4), ["puree"], portion: 250, "1 assiette"),
        LexiconEntry(Food("Gratin", kcal: 140, protein: 5, carbs: 12, fat: 8), ["gratin", "lasagne", "hachi parmentier", "parmentier"], portion: 300, "1 part"),
        // Protéines
        LexiconEntry(Foods.chicken, ["poulet", "blanc de poulet", "dinde", "escalope"], portion: 150),
        LexiconEntry(Food("Steak", kcal: 200, protein: 26, carbs: 0, fat: 10), ["steak", "boeuf", "entrecote", "bavette", "steak hache", "viande"], portion: 150, "1 steak"),
        LexiconEntry(Foods.salmon, ["saumon"], portion: 130, "1 pavé"),
        LexiconEntry(Foods.tuna, ["thon"], portion: 100, "1 boîte"),
        LexiconEntry(Food("Poisson", kcal: 110, protein: 22, carbs: 0, fat: 2), ["poisson", "cabillaud", "colin", "merlu", "dorade"], portion: 150, "1 filet"),
        LexiconEntry(Food("Jambon", kcal: 115, protein: 20, carbs: 1, fat: 3.5, unit: FoodUnit(grams: 40, singular: "tranche", plural: "tranches")), ["jambon"], portion: 80, "2 tranches", units: ["tranche": 40]),
        LexiconEntry(Food("Saucisse", kcal: 300, protein: 13, carbs: 2, fat: 27, unit: FoodUnit(grams: 100, singular: "saucisse", plural: "saucisses")), ["saucisse", "merguez", "chipolata", "knacki"], portion: 100, "1 saucisse"),
        LexiconEntry(Foods.eggs, ["oeuf"], portion: 110, "2 œufs"),
        LexiconEntry(Foods.tofu, ["tofu"], portion: 150),
        LexiconEntry(Food("Whey", kcal: 380, protein: 75, carbs: 8, fat: 6), ["whey", "shaker", "shake proteine", "proteine en poudre"], portion: 30, "1 dose"),
        LexiconEntry(Food("Barre protéinée", kcal: 350, protein: 30, carbs: 35, fat: 10, unit: FoodUnit(grams: 60, singular: "barre", plural: "barres")), ["barre proteinee", "barre de proteine"], portion: 60, "1 barre"),
        // Féculents, pain, petit-déjeuner
        LexiconEntry(Food("Pain", kcal: 270, protein: 9, carbs: 55, fat: 1.5, unit: FoodUnit(grams: 35, singular: "tranche", plural: "tranches")), ["pain", "tartine"], portion: 70, "2 tranches", units: ["baguette": 250]),
        // Une baguette entière pèse environ 250 g, pas une tranche.
        LexiconEntry(Food("Baguette", kcal: 270, protein: 9, carbs: 55, fat: 1.5, unit: FoodUnit(grams: 250, singular: "baguette", plural: "baguettes")), ["baguette", "baguette de pain"], portion: 70, "1 morceau"),
        LexiconEntry(Foods.wholeBread, ["pain complet"], portion: 70, "2 tranches", units: ["tranche": 35]),
        LexiconEntry(Food("Croissant", kcal: 410, protein: 8, carbs: 45, fat: 21, unit: FoodUnit(grams: 60, singular: "croissant", plural: "croissants")), ["croissant"], portion: 60, "1 croissant"),
        LexiconEntry(Food("Pain au chocolat", kcal: 420, protein: 7, carbs: 46, fat: 23, unit: FoodUnit(grams: 70, singular: "pain au chocolat", plural: "pains au chocolat")), ["pain au chocolat", "chocolatine", "viennoiserie"], portion: 70, "1 pièce"),
        LexiconEntry(Food("Céréales", kcal: 380, protein: 8, carbs: 75, fat: 5), ["cereale", "muesli", "granola"], portion: 40, "1 bol", units: ["bol": 40]),
        LexiconEntry(Foods.oats, ["flocon d avoine", "avoine", "porridge"], portion: 60),
        LexiconEntry(Food("Pommes de terre", kcal: 80, protein: 2, carbs: 17, fat: 0.1), ["pomme de terre", "patate"], portion: 250),
        LexiconEntry(Foods.sweetPotato, ["patate douce"], portion: 200),
        LexiconEntry(Foods.lentils, ["lentille"], portion: 200),
        LexiconEntry(Foods.chickpeas, ["pois chiche"], portion: 150),
        LexiconEntry(Foods.quinoa, ["quinoa"], portion: 150),
        // Produits laitiers
        LexiconEntry(Food("Yaourt", kcal: 60, protein: 4, carbs: 5, fat: 3, unit: FoodUnit(grams: 125, singular: "yaourt", plural: "yaourts")), ["yaourt", "yogourt", "yoghourt"], portion: 125, "1 yaourt"),
        LexiconEntry(Foods.greekYogurt, ["yaourt grec"], portion: 150, "1 pot", units: ["pot": 150]),
        LexiconEntry(Foods.skyr, ["skyr"], portion: 150, "1 pot", units: ["pot": 150]),
        LexiconEntry(Foods.cottageCheese, ["fromage blanc"], portion: 150, "1 pot"),
        LexiconEntry(Food("Fromage", kcal: 380, protein: 24, carbs: 0, fat: 31), ["fromage", "comte", "emmental", "camembert", "chevre", "raclette", "mozzarella"], portion: 30, "1 morceau"),
        LexiconEntry(Food("Lait", kcal: 46, protein: 3.3, carbs: 4.8, fat: 1.6), ["lait"], portion: 250, "1 verre"),
        LexiconEntry(Food("Beurre", kcal: 740, protein: 0.7, carbs: 0.6, fat: 82), ["beurre"], portion: 10, "1 noisette"),
        // Fruits, légumes
        LexiconEntry(Foods.banana, ["banane"], portion: 120, "1 banane"),
        LexiconEntry(Foods.apple, ["pomme"], portion: 150, "1 pomme"),
        LexiconEntry(Food("Orange", kcal: 47, protein: 0.9, carbs: 11.8, fat: 0.1, unit: FoodUnit(grams: 150, singular: "orange", plural: "oranges")), ["orange", "clementine", "mandarine"], portion: 150, "1 orange"),
        LexiconEntry(Food("Fruit", kcal: 55, protein: 0.7, carbs: 13, fat: 0.3, unit: FoodUnit(grams: 150, singular: "fruit", plural: "fruits")), ["fruit", "poire", "peche", "kiwi", "raisin", "compote", "salade de fruit"], portion: 150, "1 fruit"),
        LexiconEntry(Foods.berries, ["fruit rouge", "fraise", "framboise", "myrtille"], portion: 100),
        LexiconEntry(Food("Dattes", kcal: 282, protein: 2.5, carbs: 75, fat: 0.4, unit: FoodUnit(grams: 8, singular: "datte", plural: "dattes")), ["datte", "fruit sec", "figue seche", "abricot sec", "pruneau"], portion: 24, "3 dattes"),
        LexiconEntry(Foods.avocado, ["avocat"], portion: 100, "½ avocat"),
        LexiconEntry(Food("Légumes", kcal: 30, protein: 1.5, carbs: 5, fat: 0.3), ["legume", "carotte", "poivron", "epinard", "chou", "ratatouille", "poelee de legume"], portion: 200),
        LexiconEntry(Foods.broccoli, ["brocoli"], portion: 150),
        LexiconEntry(Foods.greenBeans, ["haricot vert", "haricot"], portion: 150),
        LexiconEntry(Foods.zucchini, ["courgette"], portion: 150),
        LexiconEntry(Foods.tomato, ["tomate"], portion: 150),
        LexiconEntry(Food("Salade verte", kcal: 15, protein: 1.3, carbs: 2, fat: 0.2), ["salade", "salade verte", "crudite"], portion: 80, "1 bol"),
        // Gras, sauces, en-cas
        LexiconEntry(Foods.oliveOil, ["huile", "huile d olive", "vinaigrette"], portion: 10, "1 cuillère", units: ["cuillere": 10]),
        LexiconEntry(Food("Sauce", kcal: 680, protein: 1, carbs: 2, fat: 75), ["mayonnaise", "mayo", "sauce", "ketchup", "pesto"], portion: 15, "1 cuillère"),
        LexiconEntry(Foods.almonds, ["amande"], portion: 30, "1 poignée"),
        LexiconEntry(Food("Olives", kcal: 145, protein: 1, carbs: 4, fat: 15), ["olive"], portion: 30, "1 poignée"),
        LexiconEntry(Food("Noix", kcal: 650, protein: 15, carbs: 14, fat: 65), ["noix", "noisette", "cajou", "pistache", "oleagineux"], portion: 30, "1 poignée"),
        LexiconEntry(Food("Houmous", kcal: 300, protein: 8, carbs: 14, fat: 24), ["houmou", "hummu"], portion: 50),
        LexiconEntry(Food("Chocolat", kcal: 540, protein: 6, carbs: 50, fat: 33), ["chocolat"], portion: 20, "2 carrés"),
        LexiconEntry(Food("Biscuits", kcal: 450, protein: 6, carbs: 65, fat: 18), ["biscuit", "cookie", "gateau", "brownie", "madeleine", "patisserie"], portion: 50, units: ["part": 100]),
        LexiconEntry(Food("Glace", kcal: 200, protein: 3.5, carbs: 24, fat: 10), ["glace", "sorbet"], portion: 100, "2 boules"),
        LexiconEntry(Food("Chips", kcal: 530, protein: 6, carbs: 50, fat: 34), ["chip"], portion: 30, "1 poignée"),
        // Boissons
        LexiconEntry(Food("Soda zéro", kcal: 0.3, protein: 0, carbs: 0, fat: 0), ["coca zero", "pepsi max", "soda zero"], portion: 330, "1 canette"),
        LexiconEntry(Food("Soda", kcal: 42, protein: 0, carbs: 10.6, fat: 0), ["coca", "soda", "pepsi", "fanta", "ice tea", "the glace", "limonade"], portion: 330, "1 canette", units: ["verre": 250]),
        LexiconEntry(Food("Jus de fruits", kcal: 45, protein: 0.7, carbs: 10, fat: 0.2), ["jus", "jus d orange", "jus de fruit"], portion: 200, "1 verre"),
        LexiconEntry(Food("Bière", kcal: 43, protein: 0.5, carbs: 3.6, fat: 0, unit: FoodUnit(grams: 250, singular: "bière", plural: "bières")), ["biere", "pinte"], portion: 250, "1 bière", units: ["pinte": 500]),
        LexiconEntry(Food("Vin", kcal: 85, protein: 0.1, carbs: 2.6, fat: 0), ["vin", "rose", "champagne"], portion: 125, "1 verre", units: ["verre": 125]),
        LexiconEntry(Food("Café", kcal: 2, protein: 0.1, carbs: 0, fat: 0, unit: FoodUnit(grams: 100, singular: "café", plural: "cafés")), ["cafe", "expresso", "the", "tisane", "infusion"], portion: 100, "1 tasse"),
        LexiconEntry(Food("Eau", kcal: 0, protein: 0, carbs: 0, fat: 0), ["eau"], portion: 250, "1 verre"),
        LexiconEntry(Food("Sucre", kcal: 400, protein: 0, carbs: 100, fat: 0, unit: FoodUnit(grams: 5, singular: "sucre", plural: "sucres")), ["sucre", "miel", "confiture", "nutella", "pate a tartiner"], portion: 15, "1 cuillère"),
    ]
}

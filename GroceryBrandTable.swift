// Fichier généré par scripts/openfoodfacts/build.py : ne pas modifier à la main.
// Données Open Food Facts (openfoodfacts.org), licence ODbL.

enum GroceryBrandTable {
    static let entries: [String: GroceryBrandEntry] = [
        "Flocons d'avoine": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "flocons d'avoine", must: ["avoine"], exclude: ["biscuit", "barre", "chocolat", "granola", "muesli", "boisson", "cookie", "porridge aux", "son"], lead: ["flocon", "avoine"]),
            picks: [
                GroceryBrandPick(brand: "Bjorg", product: "Flocons d'avoine", nutriScore: "A", nova: 1, barcode: "3229820019307"),
                GroceryBrandPick(brand: "Quaker", product: "Flocons d'avoine complète", nutriScore: "A", nova: 1, barcode: "3168930009078"),
            ]
        ),
        "Yaourt grec 0 %": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "yaourt grec 0%", must: ["grec"], exclude: ["fruit", "vanille", "miel", "fraise", "citron", "coco", "framboise", "mangue", "peche", "abricot", "cerise", "myrtille"], lead: ["yaourt", "yogourt", "grec"], maxFat: 1, isProteinSource: true),
            picks: [
                GroceryBrandPick(brand: "Delta", product: "Yaourt grec authentique", nutriScore: "A", nova: 1, barcode: "5201037711234"),
                GroceryBrandPick(brand: "Iorgos", product: "Yaourt grec", nutriScore: "A", nova: 1, barcode: "3701002408197"),
            ]
        ),
        "Skyr nature": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "skyr nature", must: ["skyr"], exclude: ["fraise", "vanille", "framboise", "myrtille", "mangue", "citron", "coco", "boire", "fruit", "peche", "abricot", "cerise", "miel", "chocolat"], lead: ["skyr"], isProteinSource: true),
            picks: [
                GroceryBrandPick(brand: "Yoplait", product: "Skyr", nutriScore: "A", nova: 1, barcode: "3329770073265"),
                GroceryBrandPick(brand: "Milbona", product: "Skyr", nutriScore: "A", nova: 1, barcode: "4056489491217"),
            ]
        ),
        "Fromage blanc 0 %": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "fromage blanc 0%", must: ["fromage", "blanc"], exclude: ["fruit", "vanille", "sucre", "fraise", "framboise", "aromatise"], lead: ["fromage blanc"], maxFat: 1, isProteinSource: true),
            picks: [
                GroceryBrandPick(brand: "U", product: "Fromage blanc nature 0%MG - 1kg", nutriScore: "A", nova: 1, barcode: "3256224235408"),
                GroceryBrandPick(brand: "Carrefour Classic", product: "Fromage Blanc Nature 0%", nutriScore: "A", nova: 3, barcode: "3270190020936"),
            ]
        ),
        "Amandes": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "amandes", must: ["amande"], exclude: ["barre", "biscuit", "boisson", "caramel", "chocolat", "dragee", "effilee", "fruits", "fumee", "grille", "lait", "miel", "noisette", "pate", "poudre", "puree", "sale"], lead: ["amande"]),
            picks: [
                GroceryBrandPick(brand: "Alesto", product: "Amandes", nutriScore: "A", nova: 1, barcode: "20724696"),
                GroceryBrandPick(brand: "Natural Happiness", product: "Amandes", nutriScore: "A", nova: 1, barcode: "8711299020953"),
            ]
        ),
        "Pain complet": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "pain complet", must: ["pain", "complet"], exclude: ["burger", "hot dog", "brioche"], lead: ["pain"]),
            picks: [
                GroceryBrandPick(brand: "Bjorg", product: "Pain complet 3 céréales", nutriScore: "A", nova: 3, barcode: "3229820019192"),
                GroceryBrandPick(brand: "Carrefour BIO", product: "Pain complet 3 céréales", nutriScore: "A", nova: 3, barcode: "3560071459468"),
            ]
        ),
        "Tofu ferme": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "tofu nature", must: ["tofu"], exclude: ["fume", "soyeux", "dessert", "herbe", "saucisse", "galette", "pane", "marine", "curry", "basilic", "olive", "tomate"], lead: ["tofu"], isProteinSource: true),
            picks: [
                GroceryBrandPick(brand: "Bjorg", product: "Tofu nature", nutriScore: "A", nova: 3, barcode: "3229820762692"),
                GroceryBrandPick(brand: "Sojami", product: "Tofu lactofermenté nature", nutriScore: "A", nova: 3, barcode: "3576566001005"),
            ]
        ),
        "Riz basmati": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "riz basmati", must: ["basmati"], exclude: ["express", "micro", "poelee", "plat", "sachet cuisson", "cuisine", "legume"], lead: ["riz"]),
            picks: [
                GroceryBrandPick(brand: "Taureau Ailé", product: "Riz basmati du Penjab", nutriScore: "B", nova: 1, barcode: "3760341070465"),
                GroceryBrandPick(brand: "Carrefour BIO", product: "Riz basmati complet", nutriScore: "B", nova: 1, barcode: "3560071254179"),
            ]
        ),
        "Pâtes complètes": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "pâtes complètes", must: ["complet"], exclude: ["avoine", "flocon", "lasagne", "pain", "plat", "riz", "salade", "sauce"], lead: ["pate", "spaghetti", "penne", "fusilli", "coquillette", "torsade", "tagliatelle"]),
            picks: [
                GroceryBrandPick(brand: "Carrefour", product: "Fusilli Blé complet", nutriScore: "A", nova: 1, barcode: "3560070825493"),
                GroceryBrandPick(brand: "Bio Village", product: "Torsades complètes", nutriScore: "A", nova: 1, barcode: "3564707000109"),
            ]
        ),
        "Quinoa": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "quinoa", must: ["quinoa"], exclude: ["barre", "biscuit", "boulgour", "flocon", "galette", "melange", "pain", "pate", "plat", "poelee", "salade", "soufle", "spaghetti"], lead: ["quinoa"]),
            picks: [
                GroceryBrandPick(brand: "Tipiak", product: "Quinoa gourmand", nutriScore: "A", nova: 1, barcode: "3600900011037"),
                GroceryBrandPick(brand: "Carrefour", product: "Quinoa bio", nutriScore: "A", nova: 1, barcode: "3560070826391"),
            ]
        ),
        "Lentilles": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "lentilles vertes", must: ["lentille"], exclude: ["salade", "cuisine", "saucisse", "plat", "soupe", "pate", "chips", "farine", "petit sale"], lead: ["lentille"], isProteinSource: true),
            picks: [
                GroceryBrandPick(brand: "Marque Repère", product: "Lentilles vertes", nutriScore: "A", nova: 1, barcode: "3564700001226"),
                GroceryBrandPick(brand: "Golden Sun", product: "Lentilles vertes", nutriScore: "A", nova: 1, barcode: "4056489032090"),
            ]
        ),
        "Pois chiches": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "pois chiches", must: ["pois", "chiche"], exclude: ["houmous", "hummus", "farine", "grille", "snack", "chips", "falafel", "salade", "plat", "curry", "pate"], lead: ["pois chiche"], isProteinSource: true),
            picks: [
                GroceryBrandPick(brand: "Prosain", product: "Pois chiches sans sel ajouté", nutriScore: "A", nova: 1, barcode: "3335880004273"),
                GroceryBrandPick(brand: "D'aucy", product: "Pois chiches HVE Bien cultivés d'aucy 250g", nutriScore: "B", nova: 1, barcode: "3017800502051"),
            ]
        ),
        "Thon au naturel": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "thon au naturel", must: ["thon", "naturel"], exclude: ["salade", "rillette", "miette a l huile", "sauce", "tomate"], lead: ["thon", "miette", "filet de thon"], isProteinSource: true),
            picks: [
                GroceryBrandPick(brand: "Odyssée", product: "Thon albacore au naturel tranche emboité cru 200g 140g (1/4)", nutriScore: "A", nova: 1, barcode: "3250390806011"),
                GroceryBrandPick(brand: "Connétable", product: "Thon entier naturel", nutriScore: "A", nova: 1, barcode: "3263670399516"),
            ]
        ),
        "Feta": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "feta", must: ["feta"], exclude: ["salade", "salad", "pate", "pasta", "marine", "tarte", "chips", "epinard", "spinach", "olive", "tomate", "tomato", "dessert", "huile", "cheese"], lead: ["feta"]),
            picks: [
                GroceryBrandPick(brand: "Islos", product: "FETA AOP GRECQUE", nutriScore: "D", nova: 3, barcode: "3272770015523"),
                GroceryBrandPick(brand: "Les Croisés", product: "Feta", nutriScore: "D", nova: 3, barcode: "3564706614673"),
            ]
        ),
        "Huile d'olive": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "huile d'olive vierge extra", must: ["huile", "olive"], exclude: ["tapenade", "pizza", "aromatisee", "spray", "basilic", "ail", "piment", "truffe", "citron"], lead: ["huile"]),
            picks: [
                GroceryBrandPick(brand: "Carapelli", product: "Huile d'olive vierge extra Bio Classico", nutriScore: "B", nova: 2, barcode: "8002470023727"),
                GroceryBrandPick(brand: "Terra Delyssa", product: "Huile d'olive vierge extra (Biologique)", nutriScore: "B", nova: 2, barcode: "6191509905058"),
            ]
        ),
        "Fruits rouges": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "fruits rouges surgelés", must: ["fruits", "rouges"], exclude: ["coulis", "confiture", "jus", "yaourt", "compote", "sorbet", "glace", "tarte", "the", "infusion", "biscuit", "sirop", "nectar", "boisson", "smoothie", "dessert", "gateau", "muesli", "cereale"], lead: ["fruits rouges", "melange de fruits rouges", "melange fruits rouges"]),
            picks: [
                GroceryBrandPick(brand: "Marque Repère", product: "Fruits rouges", nutriScore: "A", nova: 1, barcode: "3564700683460"),
                GroceryBrandPick(brand: "Fresh Cueillette", product: "Fruits Rouges", nutriScore: "A", nova: 1, barcode: "3760287430286"),
            ]
        ),
        "Haricots verts": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "haricots verts", must: ["haricot", "vert"], exclude: ["salade", "plat", "poelee", "lardon", "melange", "jardiniere"], lead: ["haricot"]),
            picks: [
                GroceryBrandPick(brand: "Jardin Bio étic", product: "Haricots verts extra-fins sans sel ajouté", nutriScore: "A", nova: 1, barcode: "3760020505943"),
                GroceryBrandPick(brand: "Bonduelle", product: "Haricots verts SRP 750G", nutriScore: "A", nova: 1, barcode: "3083681115949"),
            ]
        ),
        "Bœuf haché 5 %": GroceryBrandEntry(
            query: GroceryBrandQuery(terms: "steak haché 5%", must: ["hache", "5"], exclude: ["15", "20", "vegetal", "soja", "poulet", "veau", "porc", "sauce", "burger", "lasagne", "parmentier", "boulette"], lead: ["steak", "hache", "bœuf", "boeuf"], isProteinSource: true),
            picks: [
                GroceryBrandPick(brand: "Picard", product: "Steaks haches pur boeuf 5% surgeles", nutriScore: "A", nova: 1, barcode: "3270160141371"),
                GroceryBrandPick(brand: "Intermarché", product: "Steaks Hachés 5% MG", nutriScore: "A", nova: 1, barcode: "3250390016342"),
            ]
        ),
    ]

    /// Marque affichée pour une marque d'Open Food Facts (normalisée) ; vide : marque écartée.
    static let brandAliases: [String: String] = ["bjorg et cie": "Bjorg", "pepsico france": "Quaker", "yoplait skyr": "Yoplait", "classic": "Carrefour Classic", "fresh cueillette": "Fresh Cueillette", "natural hapiness": "Natural Happiness", "oluf lorentzen as": "", "delta": "Delta", "iorgos": "Iorgos", "islos": "Islos", "odyssee": "Odyssée"]
}

import AIRouter
import FoundationModels
import Nutrition

/// Estimation d'un aliment absent du catalogue par le modèle Apple embarqué : gratuit, hors ligne.
///
/// Appelé seulement pour les morceaux de phrase que le catalogue ne reconnaît pas
/// (voir `MealDescriber.describe`). Ses chiffres repassent par les bornes du package.
struct OnDeviceMealModel: MealLanguageModel {
    /// Lecteur de repas de l'app : catalogue, puis modèle embarqué s'il est disponible.
    static func describer() -> MealDescriber {
        guard OnDeviceCommandModel.isAvailable else { return MealDescriber() }
        return MealDescriber(router: AIRouter(availableTiers: [.deterministic, .onDevice]), model: OnDeviceMealModel())
    }

    private static let instructions = """
        Tu estimes les calories et les macronutriments d'aliments décrits en français.
        Sans quantité précisée, prends une portion française habituelle pour un adulte.
        Donne des valeurs réalistes, proches des tables nutritionnelles, sans arrondir à l'excès.
        """

    func estimate(_ text: String) async throws -> [FoodEstimateDraft] {
        let session = LanguageModelSession(instructions: Self.instructions)
        let estimated = try await session.respond(to: text, generating: EstimatedMeal.self).content
        return estimated.foods.map {
            FoodEstimateDraft(
                name: $0.name,
                grams: Double($0.grams),
                kcal: Double($0.kcal),
                proteinG: Double($0.proteinG),
                carbsG: Double($0.carbsG),
                fatG: Double($0.fatG)
            )
        }
    }
}

@Generable
struct EstimatedMeal {
    @Guide(description: "Chaque aliment ou plat mentionné, un par entrée")
    var foods: [EstimatedFood]
}

@Generable
struct EstimatedFood {
    @Guide(description: "Nom court de l'aliment, en français")
    var name: String
    @Guide(description: "Poids de la portion en grammes")
    var grams: Int
    @Guide(description: "Calories de la portion")
    var kcal: Int
    @Guide(description: "Protéines de la portion, en grammes")
    var proteinG: Int
    @Guide(description: "Glucides de la portion, en grammes")
    var carbsG: Int
    @Guide(description: "Lipides de la portion, en grammes")
    var fatG: Int
}

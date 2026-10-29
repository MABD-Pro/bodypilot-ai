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
        return MealDescriber(router: AIRouter(availableTiers: [.deterministic, .onDevice]), model: OnDeviceMealModel(), usage: AIUsageStore.shared)
    }

    private static let instructions = """
        Tu estimes les calories et les macronutriments d'aliments décrits en français.
        Si une quantité est écrite (« 120 g »), garde-la ; sinon prends une portion française habituelle pour un adulte.
        Donne les valeurs pour 100 g, comme la table Ciqual, sans arrondir à l'excès.
        """

    func estimate(_ text: String) async throws -> [FoodEstimateDraft] {
        let session = LanguageModelSession(instructions: Self.instructions)
        let estimated = try await session.respond(to: text, generating: EstimatedMeal.self).content
        // Valeurs pour 100 g, ramenées à la portion ici : le modèle connaît mieux les densités
        // des tables que le total d'une portion (un pot de 120 g estimé à 900 kcal sinon).
        return estimated.foods.map {
            let factor = Double($0.grams) / 100
            return FoodEstimateDraft(
                name: $0.name,
                grams: Double($0.grams),
                kcal: Double($0.kcalPer100g) * factor,
                proteinG: $0.proteinPer100g * factor,
                carbsG: $0.carbsPer100g * factor,
                fatG: $0.fatPer100g * factor
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
    @Guide(description: "Calories pour 100 g")
    var kcalPer100g: Int
    @Guide(description: "Protéines pour 100 g, en grammes")
    var proteinPer100g: Double
    @Guide(description: "Glucides pour 100 g, en grammes")
    var carbsPer100g: Double
    @Guide(description: "Lipides pour 100 g, en grammes")
    var fatPer100g: Double
}

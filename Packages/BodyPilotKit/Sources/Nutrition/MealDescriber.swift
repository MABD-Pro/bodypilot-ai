import AIRouter
import BodyPilotCore
import Foundation

/// Estimation brute d'un aliment par un modèle de langage, avant contrôle.
public struct FoodEstimateDraft: Sendable, Equatable {
    public var name: String
    public var grams: Double
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double

    public init(name: String, grams: Double, kcal: Double, proteinG: Double, carbsG: Double, fatG: Double) {
        self.name = name
        self.grams = grams
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
}

/// Modèle capable d'estimer un aliment inconnu du catalogue (Foundation Models sur l'iPhone).
/// Implémenté dans l'app : le package reste indépendant du fournisseur.
public protocol MealLanguageModel: Sendable {
    func estimate(_ text: String) async throws -> [FoodEstimateDraft]
}

/// « Qu'as-tu mangé ? » en texte libre : catalogue d'abord, modèle embarqué pour le reste.
///
/// Passe par l'AIRouter : le catalogue couvre les repas courants, gratuitement et hors ligne.
/// Seuls les morceaux inconnus vont au modèle embarqué, jamais au cloud, et ses chiffres
/// repassent par des bornes réalistes.
public struct MealDescriber: Sendable {
    public static let feature = "meal-description"
    static let maxModelInputLength = 280

    public var router: AIRouter
    public var model: (any MealLanguageModel)?

    public init(router: AIRouter = AIRouter(availableTiers: [.deterministic]), model: (any MealLanguageModel)? = nil) {
        self.router = router
        self.model = model
    }

    /// Catalogue seul : instantané.
    public func parse(_ text: String) -> MealParse {
        MealTextParser.parse(text)
    }

    /// Catalogue, puis le modèle embarqué pour les aliments qu'il ne connaît pas.
    public func describe(_ text: String) async -> MealParse {
        var parse = MealTextParser.parse(text)
        let unknown = parse.unrecognized.joined(separator: ", ")
        guard !unknown.isEmpty, unknown.count <= Self.maxModelInputLength, let model,
              case .route(let tier) = router.route(AIRequest(feature: Self.feature, minimumTier: .onDevice), usage: AIUsageSnapshot()),
              tier == .onDevice,
              let drafts = try? await model.estimate(unknown)
        else { return parse }
        let estimated = drafts.compactMap(Self.checked)
        guard !estimated.isEmpty else { return parse }
        parse.foods += estimated
        parse.unrecognized = []
        return parse
    }

    /// Bornes réalistes : portion entre 1 g et 1,5 kg, densité sous 900 kcal/100 g,
    /// calories recalculées depuis les macros si le modèle se contredit.
    static func checked(_ draft: FoodEstimateDraft) -> DescribedFood? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, (1...1500).contains(draft.grams),
              draft.proteinG >= 0, draft.carbsG >= 0, draft.fatG >= 0
        else { return nil }
        let fromMacros = draft.proteinG * 4 + draft.carbsG * 4 + draft.fatG * 9
        let kcal = abs(draft.kcal - fromMacros) > max(30, fromMacros * 0.3) ? fromMacros : draft.kcal
        guard kcal >= 0, kcal / draft.grams * 100 <= 900 else { return nil }
        return DescribedFood(
            name: name.prefix(1).uppercased() + name.dropFirst(),
            grams: draft.grams,
            quantityLabel: "≈ \(Int(draft.grams.rounded())) g",
            macros: Macros(kcal: kcal, proteinG: draft.proteinG, carbsG: draft.carbsG, fatG: draft.fatG),
            isEstimate: true
        )
    }
}

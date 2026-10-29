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

extension FoodEstimateDraft {
    /// La même estimation pour un autre poids : la densité du modèle est gardée.
    func scaled(to grams: Double) -> FoodEstimateDraft {
        let factor = grams / self.grams
        return FoodEstimateDraft(name: name, grams: grams, kcal: kcal * factor, proteinG: proteinG * factor, carbsG: carbsG * factor, fatG: fatG * factor)
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
    /// Chaque appel au modèle y est mesuré (latence, réussite).
    public var usage: (any AIUsageRecording)?

    public init(
        router: AIRouter = AIRouter(availableTiers: [.deterministic]),
        model: (any MealLanguageModel)? = nil,
        usage: (any AIUsageRecording)? = nil
    ) {
        self.router = router
        self.model = model
        self.usage = usage
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
              let drafts = await router.run(AIRequest(feature: Self.feature, minimumTier: .onDevice), on: .onDevice, recorder: usage, {
                  try await model.estimate(unknown)
              })
        else { return parse }
        // Un aliment estimé par morceau inconnu : la quantité écrite (« 120 g de … ») prime sur
        // la portion choisie par le modèle, qui se trompe plus souvent sur le poids que sur la densité.
        var portions = drafts.map { ($0, nil as String?) }
        if drafts.count == parse.unrecognized.count {
            for (index, segment) in parse.unrecognized.enumerated() {
                let normalized = MealTextParser.normalize(MealTextParser.numbersRead(in: segment))
                guard let written = MealTextParser.explicitQuantity(in: normalized), drafts[index].grams > 0 else { continue }
                portions[index] = (drafts[index].scaled(to: written.grams), written.label)
            }
        }
        let estimated = portions.compactMap { Self.checked($0.0, writtenLabel: $0.1) }
        guard !estimated.isEmpty else { return parse }
        parse.foods += estimated
        // Moins d'aliments estimés que de morceaux inconnus : on ne sait pas lesquels manquent,
        // ils restent signalés pour que l'utilisateur les précise.
        if estimated.count >= parse.unrecognized.count { parse.unrecognized = [] }
        return parse
    }

    /// Portions que le modèle embarqué peut choisir, en grammes : une liste fermée plutôt qu'un poids libre.
    public static let modelPortions: [String: Double] = [
        "pot": 125, "bol": 300, "assiette": 300, "part": 150, "pièce": 100, "verre": 200,
        "tranche": 35, "poignée": 30, "cuillère": 15,
    ]
    public static let modelPortionNames = ["pot", "bol", "assiette", "part", "pièce", "verre", "tranche", "poignée", "cuillère"]
    public static let defaultModelPortion: Double = 150

    /// Bornes réalistes : portion entre 1 g et 1,5 kg, densité sous 900 kcal/100 g,
    /// calories recalculées depuis les macros si le modèle se contredit.
    static func checked(_ draft: FoodEstimateDraft, writtenLabel: String? = nil) -> DescribedFood? {
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
            quantityLabel: writtenLabel ?? "≈ \(Int(draft.grams.rounded())) g",
            macros: Macros(kcal: kcal, proteinG: draft.proteinG, carbsG: draft.carbsG, fatG: draft.fatG),
            isEstimate: true
        )
    }
}

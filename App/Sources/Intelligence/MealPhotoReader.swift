import AIRouter
import FoundationModels
import Nutrition
import UIKit
import Vision

/// Photo d'un repas → phrase à corriger dans « Décrire ». Tout reste sur l'iPhone.
///
/// Modèle Apple embarqué quand il voit les images (iOS 27 et appareil compatible),
/// sinon le classifieur d'images de Vision, dont les étiquettes passent par `PhotoLabelReader`.
/// Dans les deux cas, la phrase repasse par le catalogue et les questions de portion.
@MainActor
enum MealPhotoReader {
    static let feature = "meal-photo"
    static let labelsFeature = "meal-photo-labels"

    /// Les deux lectures sont embarquées : elles passent par le routeur, qui les mesure.
    private static let router = AIRouter(availableTiers: [.deterministic, .onDevice])

    static func sentence(for image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = image.imageOrientation.cgOrientation
        if canDescribeImages,
           let described = await router.run(AIRequest(feature: feature, minimumTier: .onDevice), on: .onDevice, recorder: AIUsageStore.shared, {
               try await describedByModel(cgImage, orientation: orientation)
           }) {
            return described
        }
        return await router.run(AIRequest(feature: labelsFeature, minimumTier: .onDevice), on: .onDevice, recorder: AIUsageStore.shared) {
            try await classified(cgImage, orientation: orientation)
        }
    }

    private struct NothingRecognized: Error {}

    /// Modèle Apple embarqué capable de voir les images (iOS 27, appareil compatible).
    private static var canDescribeImages: Bool {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            let model = SystemLanguageModel.default
            return model.isAvailable && model.capabilities.contains(.vision)
        }
        #endif
        return false
    }

    private static func describedByModel(_ cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> String {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            let session = LanguageModelSession(instructions: """
                Tu regardes la photo d'un repas. Décris en français, en une phrase courte, les aliments \
                et boissons visibles avec leur quantité approximative, séparés par des virgules. \
                Exemple : « une grande assiette de pâtes carbonara, un verre de vin ». \
                Pas de calories, pas de commentaire.
                """)
            let answer = try await session.respond {
                "Qu'y a-t-il dans ce repas ?"
                Attachment(cgImage, orientation: orientation)
            }.content
            let sentence = answer.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "«»\"."))
            if !sentence.isEmpty { return sentence }
        }
        #endif
        throw NothingRecognized()
    }

    private static func classified(_ cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> String {
        let observations = try await ClassifyImageRequest().perform(on: cgImage, orientation: orientation)
        guard let sentence = PhotoLabelReader.sentence(from: observations.map { (identifier: $0.identifier, confidence: Double($0.confidence)) }) else {
            throw NothingRecognized()
        }
        return sentence
    }
}

private extension UIImage.Orientation {
    /// Les photos de l'appareil photo sont souvent tournées : Vision et le modèle doivent le savoir.
    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

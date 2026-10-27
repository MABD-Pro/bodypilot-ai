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
    static func sentence(for image: UIImage) async -> String? {
        if let described = await describedByModel(image) { return described }
        return await classified(image)
    }

    private static func describedByModel(_ image: UIImage) async -> String? {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable, model.capabilities.contains(.vision), let cgImage = image.cgImage else { return nil }
            let session = LanguageModelSession(instructions: """
                Tu regardes la photo d'un repas. Décris en français, en une phrase courte, les aliments \
                et boissons visibles avec leur quantité approximative, séparés par des virgules. \
                Exemple : « une grande assiette de pâtes carbonara, un verre de vin ». \
                Pas de calories, pas de commentaire.
                """)
            let answer = try? await session.respond {
                "Qu'y a-t-il dans ce repas ?"
                Attachment(cgImage, orientation: image.imageOrientation.cgOrientation)
            }.content
            let sentence = answer?.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "«»\"."))
            return sentence?.isEmpty == false ? sentence : nil
        }
        #endif
        return nil
    }

    private static func classified(_ image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let observations = (try? await ClassifyImageRequest().perform(on: cgImage, orientation: image.imageOrientation.cgOrientation)) ?? []
        return PhotoLabelReader.sentence(from: observations.map { (identifier: $0.identifier, confidence: Double($0.confidence)) })
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

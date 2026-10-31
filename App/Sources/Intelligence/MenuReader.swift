import AIRouter
import UIKit
import Vision

/// Photo d'une carte de restaurant → lignes de texte, lues sur l'iPhone (Vision). Rien n'est envoyé.
@MainActor
enum MenuReader {
    static let feature = "menu-photo"

    /// La lecture de texte est déterministe et locale : elle passe par le routeur, qui la mesure.
    private static let router = AIRouter(availableTiers: [.deterministic, .onDevice])

    /// Lignes de la carte, de haut en bas ; `nil` si rien n'est lisible.
    static func lines(in image: UIImage) async -> [String]? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = image.imageOrientation.menuOrientation
        return await router.run(AIRequest(feature: feature, minimumTier: .deterministic), on: .deterministic, recorder: AIUsageStore.shared) {
            var request = RecognizeTextRequest()
            request.recognitionLanguages = [Locale.Language(identifier: "fr-FR")]
            request.usesLanguageCorrection = true
            let observations = try await request.perform(on: cgImage, orientation: orientation)
            // Origine en bas à gauche : la ligne la plus haute a le plus grand y.
            let lines = observations
                .sorted { $0.boundingBox.cgRect.midY > $1.boundingBox.cgRect.midY }
                .compactMap { $0.topCandidates(1).first?.string }
            guard !lines.isEmpty else { throw NothingRead() }
            return lines
        }
    }

    private struct NothingRead: Error {}
}

private extension UIImage.Orientation {
    var menuOrientation: CGImagePropertyOrientation {
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

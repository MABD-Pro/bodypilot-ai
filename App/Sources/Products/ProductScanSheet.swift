import BodyPilotCore
import Nutrition
import SwiftUI
import OSLog
import VisionKit

/// En rayon : scanner le code-barres d'un produit, le coach dit s'il aide ton objectif.
struct ProductScanSheet: View {
    /// Démo : produit déjà lu, sans appareil photo ni réseau.
    var demoProduct: PackagedFood?

    @Environment(\.dismiss) private var dismiss
    @State private var barcode = ""
    @State private var product: PackagedFood?
    @State private var failure: ProductLookup.Failure?
    @State private var isLooking = false
    @State private var lastScanned: String?
    /// Recherche en cours : une nouvelle l'annule, un résultat tardif n'écrase pas le produit affiché.
    @State private var lookup: Task<Void, Never>?
    @FocusState private var isTypingCode: Bool

    private var canScan: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    if canScan, demoProduct == nil {
                        BarcodeScanner { code in found(code) }
                            .frame(height: 220)
                            .clipShape(.rect(cornerRadius: Theme.Radius.inner))
                    }
                    manualEntry
                    if isLooking {
                        ProgressView("Recherche du produit…")
                            .frame(maxWidth: .infinity)
                    } else if let product {
                        ProductCard(product: product)
                    } else if let failure {
                        CoachNote(text: message(for: failure), tint: Theme.nutrition)
                    }
                    Text("Seul le code-barres est envoyé à Open Food Facts, une base libre et collaborative. Les produits déjà vus se relisent hors ligne.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.l)
            }
            .navigationTitle("Scanner un produit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task {
                if let demoProduct { product = demoProduct; barcode = demoProduct.barcode }
            }
        }
    }

    private var manualEntry: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField("Code-barres", text: $barcode)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .focused($isTypingCode)
            Button("Chercher") { found(barcode) }
                .buttonStyle(.glass)
                .disabled(barcode.filter(\.isNumber).count < 8 || isLooking)
        }
    }

    private func found(_ code: String) {
        let digits = code.filter(\.isNumber)
        // Le scanner rappelle souvent pour le même code : une seule recherche à la fois par code.
        guard digits.count >= 8, digits != lastScanned || (product == nil && !isLooking) else { return }
        lastScanned = digits
        barcode = digits
        // Le pavé numérique n'a pas de touche Retour : on le ferme pour montrer le résultat.
        isTypingCode = false
        isLooking = true
        failure = nil
        lookup?.cancel()
        lookup = Task {
            let result = await ProductLookup.product(for: digits)
            guard !Task.isCancelled, digits == lastScanned else { return }
            withAnimation(Theme.springy) {
                isLooking = false
                switch result {
                case .success(let food): product = food
                case .failure(let error): product = nil; failure = error
                }
            }
        }
    }
}

extension ProductScanSheet {
    fileprivate func message(for failure: ProductLookup.Failure) -> String {
        switch failure {
        case .offline: "Pas de connexion : ce produit n'a pas encore été scanné sur cet iPhone. Réessaie quand tu as du réseau."
        case .unavailable: "Open Food Facts ne répond pas pour l'instant. Réessaie dans un moment."
        case .notFound: "Produit inconnu d'Open Food Facts. Tu peux le décrire dans « Décrire » avec ses valeurs."
        }
    }
}

/// Le produit et l'avis du coach.
private struct ProductCard: View {
    let product: PackagedFood

    var body: some View {
        let verdict = ProductVerdict.of(product)
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let brand = product.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Label(verdict.headline, systemImage: symbol(verdict.rating))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint(verdict.rating))
            Text(verdict.detail)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Pour 100\u{00A0}g")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                NutrientBreakdown(macros: product.per100g, approximate: false)
                if let serving = product.servingGrams {
                    Text("Portion indiquée : \(serving.frenchInteger)\u{00A0}g, soit \((product.per100g.kcal * serving / 100).frenchInteger)\u{00A0}kcal et \((product.per100g.proteinG * serving / 100).frenchInteger)\u{00A0}g de protéines.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let score = product.nutriScore {
                Text("Nutri-Score \(score.uppercased())")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: .capsule)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    private func symbol(_ rating: ProductVerdict.Rating) -> String {
        switch rating {
        case .great: "checkmark.seal.fill"
        case .fine: "hand.thumbsup"
        case .occasional: "exclamationmark.circle"
        }
    }

    private func tint(_ rating: ProductVerdict.Rating) -> Color {
        switch rating {
        case .great: Theme.progress
        case .fine: Theme.carbs
        case .occasional: Theme.nutrition
        }
    }
}

/// Scanner de codes-barres de VisionKit, sur l'iPhone.
private struct BarcodeScanner: UIViewControllerRepresentable {
    let found: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    /// Démarré ici plutôt qu'à la création : relancé si iOS l'a interrompu (appel, retour d'arrière-plan).
    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !controller.isScanning else { return }
        do {
            try controller.startScanning()
        } catch {
            AppLog.products.error("Scanner de codes-barres indisponible : \(error.localizedDescription, privacy: .public)")
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(found: found) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let found: (String) -> Void

        init(found: @escaping (String) -> Void) {
            self.found = found
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    found(payload)
                    return
                }
            }
        }
    }
}

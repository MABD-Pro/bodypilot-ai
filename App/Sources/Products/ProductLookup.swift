import Foundation
import Nutrition

/// Produits lus par code-barres dans Open Food Facts. Seul le code part sur Internet ; chaque
/// produit trouvé reste en cache sur l'iPhone et se relit hors ligne.
enum ProductLookup {
    enum Failure: Error, Equatable {
        case notFound
        case offline
    }

    private static let cacheKey = "productCache.v2"
    /// Produits gardés au plus (les plus anciens partent d'abord).
    private static let cacheLimit = 200

    static func product(for barcode: String) async -> Result<PackagedFood, Failure> {
        if let cached = cache[barcode] { return .success(cached) }
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json")
        components?.queryItems = [URLQueryItem(name: "fields", value: "product_name,product_name_fr,brands,serving_quantity,serving_size,nutriscore_grade,nutrition_grades,nutriments")]
        guard let url = components?.url else { return .failure(.notFound) }
        var request = URLRequest(url: url, timeoutInterval: 10)
        // Open Food Facts demande d'identifier l'app qui interroge sa base.
        request.setValue("BodyPilot/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let food = PackagedFood.fromOpenFoodFacts(data, barcode: barcode) else { return .failure(.notFound) }
            remember(food)
            return .success(food)
        } catch {
            return .failure(.offline)
        }
    }

    private struct Cache: Codable {
        var foods: [String: PackagedFood] = [:]
        var order: [String] = []
    }

    private static var stored: Cache {
        get {
            guard let data = UserDefaults.standard.data(forKey: cacheKey), let cache = try? JSONDecoder().decode(Cache.self, from: data) else { return Cache() }
            return cache
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data, forKey: cacheKey) }
        }
    }

    private static var cache: [String: PackagedFood] { stored.foods }

    private static func remember(_ food: PackagedFood) {
        var cache = stored
        cache.foods[food.barcode] = food
        cache.order.removeAll { $0 == food.barcode }
        cache.order.append(food.barcode)
        while cache.order.count > cacheLimit {
            cache.foods[cache.order.removeFirst()] = nil
        }
        stored = cache
    }
}

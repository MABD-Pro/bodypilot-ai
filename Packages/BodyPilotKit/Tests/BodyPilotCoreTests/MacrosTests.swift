import BodyPilotCore
import Foundation
import Testing

@Test func mealsSavedBeforeFibersStillDecode() throws {
    let old = Data(#"{"kcal":500,"proteinG":30,"carbsG":50,"fatG":20}"#.utf8)
    let macros = try JSONDecoder().decode(Macros.self, from: old)
    #expect(macros == Macros(kcal: 500, proteinG: 30, carbsG: 50, fatG: 20, fiberG: 0))
    let roundTrip = try JSONDecoder().decode(Macros.self, from: JSONEncoder().encode(Macros(kcal: 500, proteinG: 30, carbsG: 50, fatG: 20, fiberG: 8)))
    #expect(roundTrip.fiberG == 8)
}

@Test func fibersAddUpAndScale() {
    let meal = Macros(kcal: 400, proteinG: 30, carbsG: 40, fatG: 12, fiberG: 6)
    #expect((meal + meal).fiberG == 12)
    #expect(meal.scaled(by: 0.5).fiberG == 3)
}

@Test func energySharesFollowAtwaterFactors() throws {
    let meal = Macros(kcal: 400, proteinG: 30, carbsG: 40, fatG: 12, fiberG: 6)
    #expect(try #require(meal.energyShare(of: .protein)) == 0.3)
    #expect(try #require(meal.energyShare(of: .carbs)) == 0.4)
    #expect(abs(try #require(meal.energyShare(of: .fat)) - 0.27) < 0.001)
    #expect(meal.energyShare(of: .fiber) == nil)
    #expect(Macros.zero.energyShare(of: .protein) == nil)
}

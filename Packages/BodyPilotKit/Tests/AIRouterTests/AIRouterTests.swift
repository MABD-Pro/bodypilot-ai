import Testing
@testable import AIRouter

private let allTiers = Set(AITier.allCases)

@Test func picksCheapestCapableTier() {
    let router = AIRouter(availableTiers: allTiers)
    let request = AIRequest(feature: "weight-trend", minimumTier: .deterministic)
    #expect(router.route(request, usage: .init()) == .route(.deterministic))
}

@Test func skipsUnavailableOnDeviceModel() {
    let router = AIRouter(availableTiers: [.deterministic, .cloudEconomy, .cloudAdvanced])
    let request = AIRequest(feature: "command-parsing", minimumTier: .onDevice)
    #expect(router.route(request, usage: .init()) == .route(.cloudEconomy))
}

@Test func refusesCloudWhenCallBudgetExhausted() {
    let router = AIRouter(availableTiers: allTiers, budget: .init(maxCloudCalls: 10))
    let request = AIRequest(feature: "meal-photo", minimumTier: .cloudEconomy)
    #expect(router.route(request, usage: .init(cloudCalls: 10)) == .unavailable(.cloudBudgetExceeded))
}

@Test func refusesCloudWhenCostBudgetExhausted() {
    let router = AIRouter(availableTiers: allTiers, budget: .init(maxCloudCost: 1))
    let request = AIRequest(feature: "meal-photo", minimumTier: .cloudEconomy)
    #expect(router.route(request, usage: .init(cloudCost: 1)) == .unavailable(.cloudBudgetExceeded))
}

@Test func localTiersIgnoreCloudBudget() {
    let router = AIRouter(availableTiers: allTiers, budget: .init(maxCloudCalls: 0))
    let request = AIRequest(feature: "summary", minimumTier: .onDevice)
    #expect(router.route(request, usage: .init()) == .route(.onDevice))
}

@Test func reportsWhenNoTierCanHandleRequest() {
    let router = AIRouter(availableTiers: [.deterministic, .onDevice])
    let request = AIRequest(feature: "meal-photo", minimumTier: .cloudEconomy)
    #expect(router.route(request, usage: .init()) == .unavailable(.noCapableTierAvailable))
}

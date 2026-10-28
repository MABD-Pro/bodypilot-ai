import Foundation
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

private struct Failure: Error {}

@Test func measuredRunRecordsTierLatencyAndOutcome() async {
    let router = AIRouter(availableTiers: [.deterministic, .onDevice])
    let ledger = AIUsageLedger()
    let request = AIRequest(feature: "meal-description", minimumTier: .onDevice)
    let answer = await router.run(request, on: .onDevice, recorder: ledger) { 42 }
    let failed: Int? = await router.run(request, on: .onDevice, recorder: ledger) { throw Failure() }
    #expect(answer == 42)
    #expect(failed == nil)
    let summary = await ledger.summaries()
    #expect(summary.map(\.feature) == ["meal-description"])
    #expect(summary.first?.calls == 2)
    #expect(summary.first?.failures == 1)
    #expect(summary.first?.callsByTier == [.onDevice: 2])
}

@Test func measuredRunSkipsWorkOnAnotherTier() async {
    let router = AIRouter(availableTiers: [.deterministic])
    let ledger = AIUsageLedger()
    let answer = await router.run(AIRequest(feature: "command-parsing", minimumTier: .onDevice), on: .onDevice, recorder: ledger) { 1 }
    #expect(answer == nil)
    #expect(await ledger.records.isEmpty)
}

@Test func ledgerKeepsTheLatestCallsAndCountsTheMonthsCloudBudget() async {
    let old = Date(timeIntervalSince1970: 0)
    let records = (0..<(AIUsageLedger.capacity + 10)).map { index in
        AIUsageRecord(feature: "f", tier: index.isMultiple(of: 2) ? .cloudEconomy : .onDevice, cost: 1, latency: .milliseconds(10), succeeded: true, date: old)
    }
    let ledger = AIUsageLedger(records: records)
    #expect(await ledger.records.count == AIUsageLedger.capacity)
    await ledger.record(AIUsageRecord(feature: "f", tier: .cloudEconomy, cost: 2, latency: .milliseconds(10), succeeded: true))
    let thisMonth = await ledger.snapshot(since: Date(timeIntervalSinceNow: -60))
    #expect(thisMonth == AIUsageSnapshot(cloudCalls: 1, cloudCost: 2))
}

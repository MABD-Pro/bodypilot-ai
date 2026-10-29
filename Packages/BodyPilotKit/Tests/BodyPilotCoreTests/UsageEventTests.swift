import Testing
@testable import BodyPilotCore

@Test func usageEventNamesFollowAnalyticsRules() {
    let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
    for event in UsageEvent.allCases {
        #expect(!event.name.isEmpty && event.name.count <= 40)
        #expect(event.name.allSatisfy(allowed.contains))
        #expect(event.name.first?.isLetter == true)
        #expect(!["firebase_", "google_", "ga_"].contains { event.name.hasPrefix($0) })
    }
}

@Test func usageEventNamesAreUnique() {
    #expect(Set(UsageEvent.allCases.map(\.name)).count == UsageEvent.allCases.count)
}

import Foundation
import Testing
@testable import BodyPilotCore

@Test func entityIDEncodesAsPlainUUIDString() throws {
    let uuid = UUID()
    let data = try JSONEncoder().encode(EntityID(uuid))
    #expect(String(decoding: data, as: UTF8.self) == "\"\(uuid.uuidString)\"")
    #expect(try JSONDecoder().decode(EntityID.self, from: data) == EntityID(uuid))
}

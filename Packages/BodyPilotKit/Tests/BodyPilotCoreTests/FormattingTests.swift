import Testing
@testable import BodyPilotCore

@Test func formattingNeverShowsNegativeZero() {
    #expect((-0.04).frenchOneDecimal == "0,0")
    #expect((-0.04).frenchSignedOneDecimal == "0,0")
    #expect(0.04.frenchSignedOneDecimal == "0,0")
    #expect(0.26.frenchSignedOneDecimal == "+0,3")
    #expect((-0.5).frenchSignedOneDecimal == "-0,5")
}

@Test func formattingSurvivesValuesThatCannotBeComputed() {
    #expect(Double.nan.frenchOneDecimal == "–")
    #expect(Double.infinity.frenchInteger == "–")
    #expect(Double.nan.frenchCompact == "–")
    #expect(2150.0.frenchInteger == "2\u{202F}150")
}

import Foundation
import Testing
@testable import ProgressInsights

@Test func circleCircumferenceIsExact() {
    #expect(abs(WaistScan.circumference(width: 0.3, depth: 0.3) - .pi * 0.3) < 1e-9)
}

@Test func waistFromFrontAndSideMedians() throws {
    // 34 cm de large, 26 cm d'épaisseur : environ 94,6 cm de tour (ellipse).
    let cm = try #require(WaistScan.waistCm(frontWidths: [0.33, 0.34, 0.35, 0.80], sideDepths: [0.26, 0.26, 0.10]))
    #expect(abs(cm - 94.9) < 1.5)
    #expect(WaistScan.waistCm(frontWidths: [0.05], sideDepths: [0.05]) == nil)
    #expect(WaistScan.waistCm(frontWidths: [], sideDepths: [0.26]) == nil)
}

@Test func runFindsTheBodyAroundAPoint() {
    let mask = [false, true, true, true, false, true]
    #expect(WaistScan.run(in: mask, through: 2) == 1...3)
    #expect(WaistScan.run(in: mask, through: 0) == nil)
    #expect(WaistScan.metricLength(pixels: 100, depthMeters: 2, focalPixels: 200) == 1)
}

@Test func gapComparesScansWithSameDayTape() {
    let today = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let scans = [(date: today, cm: 95.0)]
    let tape = [(date: today, cm: 94.2)]
    #expect(abs(WaistScan.meanGapCm(scans: scans, tape: tape, calendar: utc)! - 0.8) < 1e-9)
    #expect(WaistScan.meanGapCm(scans: scans, tape: [], calendar: utc) == nil)
}

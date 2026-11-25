//
//  DeltaTTests.swift
//  SwiftMoonTests
//

import Foundation
import Testing

@testable import SwiftMoon

struct DeltaTTests {

    /// Constant terms of the Espenak–Meeus polynomials at their reference years.
    @Test(arguments: [
        (1900.0, -2.79),
        (1920.0, 21.20),
        (1950.0, 29.07),
        (1975.0, 45.45),
        (2000.0, 63.86),
    ])
    func espenakMeeusReferenceValues(year: Double, expected: Double) {
        #expect(abs(DeltaT.espenakMeeus(decimalYear: year) - expected) < 0.01)
    }

    /// The Espenak–Meeus pieces join without jumps of more than about a second.
    @Test(arguments: [1600.0, 1700, 1800, 1860, 1900, 1920, 1941, 1961, 1986, 2005, 2050, 2150])
    func espenakMeeusContinuousAtBoundaries(year: Double) {
        let before = DeltaT.espenakMeeus(decimalYear: year - 1e-6)
        let after = DeltaT.espenakMeeus(decimalYear: year)
        #expect(abs(before - after) < 1.5, "jump of \(after - before) s at \(year)")
    }

    /// The table hands over to the shifted polynomials without a jump.
    @Test(arguments: [Double(DeltaTTable.firstYear), Double(DeltaTTable.lastYear)])
    func continuousAtTableEnds(year: Double) {
        let before = DeltaT.seconds(decimalYear: year - 1e-6)
        let after = DeltaT.seconds(decimalYear: year)
        #expect(abs(before - after) < 0.01, "jump of \(after - before) s at \(year)")
    }

    @Test func tableValuesAreExactAtWholeYears() {
        for (i, value) in DeltaTTable.seconds.enumerated() {
            #expect(DeltaT.seconds(decimalYear: Double(DeltaTTable.firstYear + i)) == value)
        }
        #expect(DeltaTTable.seconds.count == DeltaTTable.lastYear - DeltaTTable.firstYear + 1)
    }

    /// Interpolating the yearly table reproduces Skyfield's ΔT at every
    /// fixture new moon to well under a second. (Both come from Skyfield;
    /// this checks the table and interpolation, not ΔT itself.)
    @Test func agreesWithSkyfield() {
        var maxError = 0.0
        for moon in Fixture.shared.newMoons {
            let year = JulianDay.decimalYear(moon.jdTT)
            let error = abs(DeltaT.seconds(decimalYear: year) - moon.deltaT)
            maxError = max(maxError, error)
            #expect(error < 1, "year \(year): \(error) s")
        }
        print("ΔT table vs Skyfield: max " + String(format: "%.2f s", maxError))
    }
}

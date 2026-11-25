//
//  MoonPhasesTests.swift
//  SwiftMoonTests
//

import Foundation
import Testing

@testable import SwiftMoon

struct MoonPhasesTests {

    /// Meeus Example 49.a: the new moon of 1977 February, k = −283,
    /// JDE 2443192.65118.
    @Test func meeusExample49a() {
        let jde = MoonPhases.newMoonJDE(k: -283)
        #expect(abs(jde - 2_443_192.65118) * 86_400 < 1)
    }

    /// ADR 3: every DE440s new moon 1900–2100 within 30 s, in TT on both
    /// sides so ΔT plays no part. Measured maximum is 17.2 s; a coefficient
    /// typo would normally blow well past 30 s.
    @Test func newMoonsMatchDE440sInTT() {
        let moons = Fixture.shared.newMoons
        #expect(moons.count == 2487)

        var maxError = 0.0
        var sumError = 0.0
        for moon in moons {
            let error = abs(MoonPhases.newMoonJDE(k: moon.k) - moon.jdTT) * 86_400
            maxError = max(maxError, error)
            sumError += error
            #expect(error <= 30, "k = \(moon.k): \(error) s")
        }
        print(
            "Meeus ch. 49 vs DE440s (TT): n = \(moons.count), mean |err| "
                + String(format: "%.1f s, max %.1f s", sumError / Double(moons.count), maxError)
        )
    }

    /// ADR 3 requirement: within 1 minute in UTC. Adds ΔT table
    /// interpolation and the UTC/UT1 difference (< 0.9 s) to the TT error.
    @Test func newMoonsMatchDE440sInUTC() {
        let moons = Fixture.shared.newMoons
        var maxError = 0.0
        for moon in moons {
            let date = SwiftMoon.newMoon(number: moon.k)
            let error = abs(date.timeIntervalSince1970 - moon.unixUT1)
            maxError = max(maxError, error)
            #expect(error <= 60, "k = \(moon.k): \(error) s")
        }
        print("Meeus ch. 49 + ΔT vs DE440s (UT): max " + String(format: "%.1f s", maxError))
    }

    @Test func lunationNumberIsInverseOfNewMoon() {
        for moon in Fixture.shared.newMoons where moon.k % 37 == 0 {
            let jde = MoonPhases.newMoonJDE(k: moon.k)
            #expect(MoonPhases.lunationNumber(containing: jde) == moon.k)
            #expect(MoonPhases.lunationNumber(containing: jde - 1e-6) == moon.k - 1)
            #expect(MoonPhases.lunationNumber(containing: jde + 14.0) == moon.k)
        }
    }
}

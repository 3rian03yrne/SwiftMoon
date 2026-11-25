//
//  IlluminationTests.swift
//  SwiftMoonTests
//

import Foundation
import Testing

@testable import SwiftMoon

struct IlluminationTests {

    /// Ch. 48 low precision vs DE440s. Measured maximum is 0.33 pp.
    @Test func fractionMatchesDE440s() {
        var maxError = 0.0
        for sample in Fixture.shared.illumination {
            let result = Illumination.compute(jde: sample.jdTT)
            let error = abs(result.fraction - sample.fraction) * 100
            maxError = max(maxError, error)
            #expect(error < 0.5, "jdTT \(sample.jdTT): \(error) pp")
        }
        print("Meeus ch. 48 illumination vs DE440s: max " + String(format: "%.3f pp", maxError))
    }

    /// Elongation should agree with Skyfield's moon_phase to a degree or so,
    /// enough for the app's 22.5°-wide phase bins.
    @Test func elongationMatchesDE440s() {
        for sample in Fixture.shared.illumination {
            let date = Date(timeIntervalSince1970: sample.unixUT1)
            let elongation = SwiftMoon.illumination(at: date).elongation
            var difference = abs(elongation - sample.elongation)
            difference = min(difference, 360 - difference)
            #expect(difference < 1.5, "jdTT \(sample.jdTT): \(difference)°")
        }
    }

    @Test func newAndFullMoon() {
        let lunation = SwiftMoon.lunation(containing: utc(2025, 8, 30))
        let atNew = SwiftMoon.illumination(at: lunation.lunationStartDate)
        #expect(atNew.fraction < 0.01)
        #expect(atNew.elongation < 2 || atNew.elongation > 358)

        // Full moon of 2025 Sep 7 18:09 UTC.
        let atFull = SwiftMoon.illumination(at: utc(2025, 9, 7, 18, 9))
        #expect(atFull.fraction > 0.99)
        #expect(abs(atFull.elongation - 180) < 2)
        #expect(atFull.phaseAngle < 5)
    }

    /// Through one lunation, elongation rises from 0 towards 360 and the
    /// Moon is waxing for the first half only.
    @Test func elongationIncreasesThroughLunation() {
        let lunation = SwiftMoon.lunation(containing: utc(2025, 8, 30))
        var previous = -1.0
        var date = lunation.lunationStartDate.addingTimeInterval(3_600)
        var sawWaning = false
        while date < lunation.lunationEndDate.addingTimeInterval(-3_600) {
            let illumination = SwiftMoon.illumination(at: date)
            #expect(illumination.elongation > previous)
            if !illumination.isWaxing { sawWaning = true }
            #expect(illumination.isWaxing != sawWaning)
            previous = illumination.elongation
            date = date.addingTimeInterval(6 * 3_600)
        }
        #expect(sawWaning)
    }
}

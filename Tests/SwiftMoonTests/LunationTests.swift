//
//  LunationTests.swift
//  SwiftMoonTests
//

import Foundation
import Testing

@testable import SwiftMoon

struct LunationTests {

    /// Lunation 0 is the new moon of 2000 Jan 6 (DE440s: 18:13:38 UT), the
    /// same numbering SwiftMoon 1.x used for its mean epoch.
    @Test func lunationZero() {
        let lunation = SwiftMoon.lunation(number: 0)
        #expect(abs(lunation.lunationStartDate.timeIntervalSince(utc(2000, 1, 6, 18, 13, 38))) < 60)
        #expect(SwiftMoon.lunation(containing: utc(2000, 1, 20)).lunationNumber == 0)
    }

    /// The true new moon of 2025 Aug 23 was at 06:06:33 UT. SwiftMoon 1.x put
    /// its mean new moon at 20:57, so 07:07 used to be lunation 316; it is
    /// now correctly 317.
    @Test func trueNewMoonReplacesMeanNewMoon() {
        let before = SwiftMoon.lunation(containing: utc(2025, 8, 23, 6, 0))
        let after = SwiftMoon.lunation(containing: utc(2025, 8, 23, 7, 7))
        #expect(before.lunationNumber == 316)
        #expect(after.lunationNumber == 317)
        #expect(abs(after.lunationStartDate.timeIntervalSince(utc(2025, 8, 23, 6, 6, 33))) < 60)
    }

    @Test func lunationContainsDate() {
        var date = utc(1900, 1, 2)
        let end = utc(2100, 12, 1)
        while date < end {
            let lunation = SwiftMoon.lunation(containing: date)
            #expect(lunation.contains(date))
            let duration = lunation.lunationEndDate.timeIntervalSince(lunation.lunationStartDate) / 86_400
            #expect(duration > 29.2 && duration < 29.9)
            date = date.addingTimeInterval(9.7 * 86_400)
        }
    }

    @Test func consecutiveLunationsShareEndpoints() {
        for k in stride(from: -1200, through: 1200, by: 50) {
            #expect(SwiftMoon.lunation(number: k).lunationEndDate == SwiftMoon.lunation(number: k + 1).lunationStartDate)
        }
    }

    /// Start is inclusive, end exclusive.
    @Test func boundaryInstants() {
        let start = SwiftMoon.newMoon(number: 317)
        #expect(SwiftMoon.lunation(containing: start).lunationNumber == 317)
        #expect(SwiftMoon.lunation(containing: start.addingTimeInterval(-1)).lunationNumber == 316)
        #expect(SwiftMoon.lunation(containing: start.addingTimeInterval(-0.001)).lunationNumber == 316)
    }

    @Test func newMoonsInInterval() {
        let moons = SwiftMoon.newMoons(from: utc(2025, 1, 1), to: utc(2026, 1, 1))
        #expect(moons.count == 12)
        #expect(moons.first.map { $0 > utc(2025, 1, 29) && $0 < utc(2025, 1, 30) } == true)
        #expect(zip(moons, moons.dropFirst()).allSatisfy { $0 < $1 })

        let start = SwiftMoon.newMoon(number: 317)
        #expect(SwiftMoon.newMoons(from: start, to: start.addingTimeInterval(1)) == [start])
        #expect(SwiftMoon.newMoons(from: start.addingTimeInterval(-1), to: start).isEmpty)
        #expect(SwiftMoon.newMoons(from: start, to: start).isEmpty)
    }

    /// Age is a plain interval, so a day across a DST change is still
    /// exactly 86,400 s (America/New_York sprang forward on 2025 Mar 9).
    @Test func ageIgnoresDST() {
        let saturday = utc(2025, 3, 8, 12)
        let sunday = saturday.addingTimeInterval(86_400)
        #expect(SwiftMoon.lunation(containing: saturday) == SwiftMoon.lunation(containing: sunday))
        #expect(SwiftMoon.age(at: sunday) - SwiftMoon.age(at: saturday) == 86_400)

        let start = SwiftMoon.lunation(containing: saturday).lunationStartDate
        #expect(SwiftMoon.age(at: saturday) == saturday.timeIntervalSince(start))
        #expect(SwiftMoon.age(at: start) == 0)
    }

    /// `lunation(containing:)` jumps straight to the lunation instead of
    /// stepping from an epoch.
    @Test func lunationLookupIsFast() {
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for year in 1900...2100 {
                _ = SwiftMoon.lunation(containing: utc(year, 6, 15))
            }
        }
        #expect(elapsed < .milliseconds(200))
    }

    @available(*, deprecated)
    @Test func deprecatedAPIStillWorks() {
        let date = utc(2025, 8, 30)
        #expect(SwiftMoon.getMoonForDate(date: date) == SwiftMoon.lunation(containing: date))
        #expect(SwiftMoon.getLunationPeriod(date: date) == SwiftMoon.lunation(containing: date))
        let periods = SwiftMoon.getLunationPeriods(date: date)
        #expect(periods.count == 318)
        #expect(periods.last == SwiftMoon.lunation(containing: date))
    }
}

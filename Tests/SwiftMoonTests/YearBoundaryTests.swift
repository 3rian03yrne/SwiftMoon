//
//  YearBoundaryTests.swift
//  SwiftMoonTests
//
//  ADR 3 calendar rules: a moon's index is the number of new moons since
//  Jan 1 00:00 in the device's time zone. Near Jan 1 the result can
//  legitimately differ between zones; these tests document that.
//

import Foundation
import Testing

@testable import SwiftMoon

struct YearBoundaryTests {

    let utcCalendar = calendar("UTC")
    let kiritimati = calendar("Pacific/Kiritimati")  // UTC+14
    let minus12 = calendar("Etc/GMT+12")  // UTC−12 (POSIX sign is inverted)

    @Test func indexCountsNewMoonsSinceJanuaryFirst() {
        // 2025: first new moon Jan 29 12:36 UT, 12 in the year.
        #expect(SwiftMoon.lunationIndex(for: utc(2025, 1, 15), calendar: utcCalendar) == (0, 12))
        #expect(SwiftMoon.lunationIndex(for: utc(2025, 2, 15), calendar: utcCalendar) == (1, 12))
        #expect(SwiftMoon.lunationIndex(for: utc(2025, 12, 31, 23), calendar: utcCalendar) == (12, 12))
    }

    @Test(arguments: [2000, 2003, 2005, 2008, 2011, 2014, 2016, 2019, 2022, 2024, 2027, 2030, 2033])
    func thirteenMoonYears(year: Int) {
        let result = SwiftMoon.lunationIndex(for: utc(year, 12, 31, 23, 59), calendar: utcCalendar)
        #expect(result == (13, 13))
    }

    /// New moon 2014 Jan 1 11:14 UT. At UTC−12 that is Dec 31 23:14 local,
    /// so it belongs to 2013 there and 2014 has only 12 new moons.
    @Test func newMoonOnJanuaryFirstDependsOnZone() {
        let noon = utc(2014, 1, 1, 12)  // 00:00 Jan 1 at UTC−12, 02:00 Jan 2 at UTC+14
        #expect(SwiftMoon.lunationIndex(for: noon, calendar: utcCalendar) == (1, 13))
        #expect(SwiftMoon.lunationIndex(for: noon, calendar: kiritimati) == (1, 13))
        #expect(SwiftMoon.lunationIndex(for: noon, calendar: minus12) == (0, 12))

        let justBefore = utc(2014, 1, 1, 11, 0)
        #expect(SwiftMoon.lunationIndex(for: justBefore, calendar: utcCalendar).index == 0)
        #expect(SwiftMoon.lunationIndex(for: justBefore, calendar: minus12).newMoonsInYear == 13)
    }

    /// New moon 2089 Dec 31 19:58 UT is already Jan 1 2090 at UTC+14.
    @Test func newMoonOnDecemberThirtyFirstDependsOnZone() {
        let date = utc(2090, 1, 1, 6)
        #expect(SwiftMoon.lunationIndex(for: date, calendar: utcCalendar).index == 0)
        #expect(SwiftMoon.lunationIndex(for: date, calendar: kiritimati).index == 1)

        let lastOf2089 = SwiftMoon.newMoons(inYearContaining: utc(2089, 6, 1), calendar: utcCalendar).last!
        #expect(lastOf2089 > utc(2089, 12, 31, 19) && lastOf2089 < utc(2089, 12, 31, 21))
        #expect(SwiftMoon.newMoons(inYearContaining: utc(2089, 6, 1), calendar: kiritimati).last! < lastOf2089)
    }

    /// The year boundary is local midnight, including a zone with DST.
    @Test func yearBoundaryInLocalZone() {
        let newYork = calendar("America/New_York")
        let moons = SwiftMoon.newMoons(inYearContaining: utc(2025, 7, 1), calendar: newYork)
        #expect(moons.count == 12)
        #expect(moons.allSatisfy { newYork.component(.year, from: $0) == 2025 })
    }
}

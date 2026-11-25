//
//  SwiftMoon.swift
//  SwiftMoon
//
//  Public, Swift-only API. All astronomy lives in `Meeus/`:
//  true new moons from Meeus ch. 49, illumination from ch. 48 (low precision),
//  TT → UT with the Espenak–Meeus ΔT polynomials.
//

import Foundation

public enum SwiftMoon {

    // MARK: Lunations

    /// The lunation (new moon to next new moon) that contains `date`.
    ///
    /// The start is inclusive and the end exclusive: at the exact instant of
    /// a new moon, the new lunation has begun.
    public static func lunation(containing date: Date) -> LunationPeriod {
        lunation(number: MoonPhases.lunationNumber(containing: JulianDay.ephemeris(date)))
    }

    /// The lunation with Meeus lunation number `k` (0 = the new moon of
    /// 2000 January 6; negative numbers are earlier).
    public static func lunation(number k: Int) -> LunationPeriod {
        LunationPeriod(
            lunationNumber: k,
            lunationStartDate: newMoon(number: k),
            lunationEndDate: newMoon(number: k + 1)
        )
    }

    /// Instant (UT) of the true new moon with lunation number `k`.
    public static func newMoon(number k: Int) -> Date {
        JulianDay.date(ephemeris: MoonPhases.newMoonJDE(k: k))
    }

    /// Instants of every new moon in the half-open interval `[start, end)`.
    public static func newMoons(from start: Date, to end: Date) -> [Date] {
        guard start < end else { return [] }
        var k = lunation(containing: start).lunationNumber
        var result: [Date] = []
        var moon = newMoon(number: k)
        if moon < start {
            k += 1
            moon = newMoon(number: k)
        }
        while moon < end {
            result.append(moon)
            k += 1
            moon = newMoon(number: k)
        }
        return result
    }

    /// Every new moon from Jan 1 00:00 of the year containing `date` up to
    /// (not including) the next Jan 1 00:00, in `calendar`'s time zone.
    public static func newMoons(
        inYearContaining date: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let year = calendar.dateInterval(of: .year, for: date) else { return [] }
        return newMoons(from: year.start, to: year.end)
    }

    /// The month-boundary rule (ADR 3): a moon begins at the instant of the
    /// astronomical new moon, and its index in the year is the number of new
    /// moons at or before `date` since Jan 1 00:00 in `calendar`'s time zone.
    ///
    /// `index` is 0 before the year's first new moon. `newMoonsInYear` is 12 or
    /// 13. Near Jan 1 the result can legitimately differ between time zones.
    public static func lunationIndex(
        for date: Date,
        calendar: Calendar = .current
    ) -> (index: Int, newMoonsInYear: Int) {
        let moons = newMoons(inYearContaining: date, calendar: calendar)
        let index = moons.lazy.filter { $0 <= date }.count
        return (index, moons.count)
    }

    /// Time elapsed since the new moon that began the lunation containing
    /// `date`. A plain interval: every day is exactly 86,400 s, DST and time
    /// zones have no effect.
    public static func age(at date: Date) -> TimeInterval {
        date.timeIntervalSince(lunation(containing: date).lunationStartDate)
    }

    // MARK: Illumination and phase

    /// Illuminated fraction and phase of the Moon at `date` (geocentric).
    public static func illumination(at date: Date) -> MoonIllumination {
        let result = Illumination.compute(jde: JulianDay.ephemeris(date))
        // Meeus's i is 180° − D − …, with D the mean elongation reduced to
        // 0..<360°, so 180° − i is the elongation on the full circle.
        let elongation = Illumination.normalized(180 - result.signedPhaseAngle)
        return MoonIllumination(
            fraction: result.fraction,
            phaseAngle: abs(180 - elongation),
            elongation: elongation
        )
    }

    // MARK: Deprecated (SwiftMoon 1.x)

    @available(*, deprecated, renamed: "lunation(containing:)")
    public static func getMoonForDate(date: Date) -> LunationPeriod {
        lunation(containing: date)
    }

    @available(*, deprecated, renamed: "lunation(containing:)")
    public static func getLunationPeriod(date: Date = Date()) -> LunationPeriod {
        lunation(containing: date)
    }

    /// Every lunation from lunation 0 (2000 January 6) through the one
    /// containing `date`. The last element contains `date`.
    @available(*, deprecated, message: "Use lunation(containing:) or lunation(number:)")
    public static func getLunationPeriods(date: Date) -> [LunationPeriod] {
        let k = lunation(containing: date).lunationNumber
        let numbers = k >= 0 ? Array(0...k) : Array((k...0).reversed())
        return numbers.map(lunation(number:))
    }
}

extension SwiftMoon {

    /// One lunation: from a true new moon to the next.
    public struct LunationPeriod: Sendable, Hashable {
        /// Meeus lunation number k (0 = the new moon of 2000 January 6).
        public let lunationNumber: Int
        /// Instant of the new moon that starts this lunation (inclusive).
        public let lunationStartDate: Date
        /// Instant of the next new moon (exclusive).
        public let lunationEndDate: Date

        public init(lunationNumber: Int, lunationStartDate: Date, lunationEndDate: Date) {
            self.lunationNumber = lunationNumber
            self.lunationStartDate = lunationStartDate
            self.lunationEndDate = lunationEndDate
        }

        public func contains(_ date: Date) -> Bool {
            lunationStartDate <= date && date < lunationEndDate
        }
    }

    /// Geocentric illumination and phase of the Moon.
    public struct MoonIllumination: Sendable, Hashable {
        /// Illuminated fraction of the disk, 0…1.
        public let fraction: Double
        /// Sun–Moon phase angle i in degrees, 0 (full) … 180 (new).
        public let phaseAngle: Double
        /// Phase on a 0..<360° scale: 0 new, 90 first quarter, 180 full,
        /// 270 last quarter.
        public let elongation: Double

        /// True between new and full moon.
        public var isWaxing: Bool { elongation < 180 }
    }
}

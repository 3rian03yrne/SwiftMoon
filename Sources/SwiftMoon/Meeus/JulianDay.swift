//
//  JulianDay.swift
//  SwiftMoon
//
//  Conversions between Foundation `Date` and Julian Day numbers.
//  Meeus, Astronomical Algorithms, 2nd ed., ch. 7 (Julian Day) and
//  ch. 10 (Dynamical Time and Universal Time).
//
//  `Date` counts SI seconds without leap seconds, which we treat as UT.
//  UTC and UT1 differ by under 0.9 s, which is negligible here.
//

import Foundation

enum JulianDay {

    /// JD of 1970-01-01 00:00 UT, the Unix epoch.
    static let unixEpoch: Double = 2_440_587.5
    /// JD of 2000-01-01 12:00 TT (J2000.0).
    static let j2000: Double = 2_451_545.0
    static let secondsPerDay: Double = 86_400

    /// Julian Day in Universal Time. No `Calendar` is involved.
    static func ut(_ date: Date) -> Double {
        unixEpoch + date.timeIntervalSince1970 / secondsPerDay
    }

    static func date(ut jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - unixEpoch) * secondsPerDay)
    }

    /// Continuous decimal year for a Julian Day, used to evaluate ΔT.
    static func decimalYear(_ jd: Double) -> Double {
        2000 + (jd - j2000) / 365.25
    }

    /// Julian Ephemeris Day (TT) for a date: JD(UT) + ΔT.
    static func ephemeris(_ date: Date) -> Double {
        let jd = ut(date)
        return jd + DeltaT.seconds(decimalYear: decimalYear(jd)) / secondsPerDay
    }

    /// Date (UT) for a Julian Ephemeris Day: JDE − ΔT.
    ///
    /// ΔT is evaluated at the JDE itself; ΔT changes by well under a second
    /// over the ~70 s difference, so no iteration is needed.
    static func date(ephemeris jde: Double) -> Date {
        let deltaT = DeltaT.seconds(decimalYear: decimalYear(jde))
        return date(ut: jde - deltaT / secondsPerDay)
    }
}

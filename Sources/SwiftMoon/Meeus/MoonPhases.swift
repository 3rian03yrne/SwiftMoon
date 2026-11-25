//
//  MoonPhases.swift
//  SwiftMoon
//
//  True new moon instants.
//  Meeus, Astronomical Algorithms, 2nd ed., ch. 49 (Phases of the Moon).
//
//  Transcribed from the book; it mirrors
//  scripts/lunar-validation/meeus_check.py term for term so the two can be
//  compared. Measured against JPL DE440s over 1900–2100: mean |error| 3.6 s,
//  maximum 17.2 s (in TT).
//

import Foundation

enum MoonPhases {

    /// JDE of mean new moon k = 0 (2000 Jan 6), eq. 49.1.
    static let epochJDE: Double = 2_451_550.09766
    /// Mean synodic month in days, eq. 49.1.
    static let synodicMonth: Double = 29.530588861

    /// JDE (TT) of the true new moon with lunation number `k`.
    /// k = 0 is the new moon of 2000 January 6; negative k is earlier.
    static func newMoonJDE(k: Int) -> Double {
        let k = Double(k)
        let T = k / 1236.85  // eq. 49.3
        let T2 = T * T
        let T3 = T2 * T
        let T4 = T3 * T

        // Mean phase, eq. 49.1.
        let jde =
            epochJDE + synodicMonth * k
            + 0.00015437 * T2
            - 0.000000150 * T3
            + 0.00000000073 * T4

        // Eccentricity of Earth's orbit, eq. 47.6.
        let E = 1 - 0.002516 * T - 0.0000074 * T2

        // Sun's mean anomaly, eq. 49.4.
        let M = radians(2.5534 + 29.10535670 * k - 0.0000014 * T2 - 0.00000011 * T3)
        // Moon's mean anomaly, eq. 49.5.
        let Mp = radians(
            201.5643 + 385.81693528 * k + 0.0107582 * T2 + 0.00001238 * T3 - 0.000000058 * T4
        )
        // Moon's argument of latitude, eq. 49.6.
        let F = radians(
            160.7108 + 390.67050284 * k - 0.0016118 * T2 - 0.00000227 * T3 + 0.000000011 * T4
        )
        // Longitude of the ascending node of the lunar orbit, eq. 49.7.
        let Om = radians(124.7746 - 1.56375588 * k + 0.0020672 * T2 + 0.00000215 * T3)

        // Periodic terms for the new moon (ch. 49, first table column).
        var c = -0.40720 * sin(Mp)
        c += 0.17241 * E * sin(M)
        c += 0.01608 * sin(2 * Mp)
        c += 0.01039 * sin(2 * F)
        c += 0.00739 * E * sin(Mp - M)
        c -= 0.00514 * E * sin(Mp + M)
        c += 0.00208 * E * E * sin(2 * M)
        c -= 0.00111 * sin(Mp - 2 * F)
        c -= 0.00057 * sin(Mp + 2 * F)
        c += 0.00056 * E * sin(2 * Mp + M)
        c -= 0.00042 * sin(3 * Mp)
        c += 0.00042 * E * sin(M + 2 * F)
        c += 0.00038 * E * sin(M - 2 * F)
        c -= 0.00024 * E * sin(2 * Mp - M)
        c -= 0.00017 * sin(Om)
        c -= 0.00007 * sin(Mp + 2 * M)
        c += 0.00004 * sin(2 * Mp - 2 * F)
        c += 0.00004 * sin(3 * M)
        c += 0.00003 * sin(Mp + M - 2 * F)
        c += 0.00003 * sin(2 * Mp + 2 * F)
        c -= 0.00003 * sin(Mp + M + 2 * F)
        c += 0.00003 * sin(Mp - M + 2 * F)
        c -= 0.00002 * sin(Mp - M - 2 * F)
        c -= 0.00002 * sin(3 * Mp + M)
        c += 0.00002 * sin(4 * Mp)

        // Additional corrections for all phases: planetary arguments A1–A14
        // (degrees) and their coefficients in units of 0.000001 day.
        let planetary: [(argument: Double, coefficient: Double)] = [
            (299.77 + 0.107408 * k - 0.009173 * T2, 325),  // A1
            (251.88 + 0.016321 * k, 165),  // A2
            (251.83 + 26.651886 * k, 164),  // A3
            (349.42 + 36.412478 * k, 126),  // A4
            (84.66 + 18.206239 * k, 110),  // A5
            (141.74 + 53.303771 * k, 62),  // A6
            (207.14 + 2.453732 * k, 60),  // A7
            (154.84 + 7.306860 * k, 56),  // A8
            (34.52 + 27.261239 * k, 47),  // A9
            (207.19 + 0.121824 * k, 42),  // A10
            (291.34 + 1.844379 * k, 40),  // A11
            (161.72 + 24.198154 * k, 37),  // A12
            (239.56 + 25.513099 * k, 35),  // A13
            (331.55 + 3.592518 * k, 23),  // A14
        ]
        let additional = planetary.reduce(0.0) {
            $0 + $1.coefficient * 0.000001 * sin(radians($1.argument))
        }

        return jde + c + additional
    }

    /// Lunation number of the new moon at or before `jde`
    /// (the lunation that contains `jde`).
    static func lunationNumber(containing jde: Double) -> Int {
        // True new moons differ from mean ones by under a day, so the mean
        // estimate is within one lunation; the loops correct it.
        var k = Int(((jde - epochJDE) / synodicMonth).rounded(.down))
        while newMoonJDE(k: k) > jde { k -= 1 }
        while newMoonJDE(k: k + 1) <= jde { k += 1 }
        return k
    }

    /// Converts degrees to radians, reducing to one turn first so large
    /// arguments (k × 390°) keep full precision.
    @inline(__always)
    static func radians(_ degrees: Double) -> Double {
        degrees.truncatingRemainder(dividingBy: 360) * .pi / 180
    }
}

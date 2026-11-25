//
//  DeltaT.swift
//  SwiftMoon
//
//  ΔT = TT − UT.
//
//  1900–2101: linear interpolation in `DeltaTTable`, a yearly table generated
//  from Skyfield's ΔT model by scripts/lunar-validation/generate_delta_t.py.
//
//  Outside that range: the Espenak–Meeus piecewise polynomials of the
//  Five Millennium Canon of Solar Eclipses (2006),
//  https://eclipse.gsfc.nasa.gov/SEcat5/deltatpoly.html, shifted by a
//  constant so they join the table without a jump.
//
//  Why not Espenak–Meeus throughout (ADR 3 amendment): its post-2005 pieces
//  are 2006 predictions that run far ahead of what Earth's rotation has done.
//  Against Skyfield they are 5 s high in 2025, 22 s in 2050 and 107 s in 2100,
//  which broke the 1-minute UTC requirement after about 2060.
//
//  The Canon's lunar secular-acceleration correction (−0.000012932 (y − 1955)²)
//  is for its ELP-2000/82 lunar ephemeris and is not applied.
//

import Foundation

enum DeltaT {

    /// ΔT in seconds for a continuous decimal year
    /// (`JulianDay.decimalYear`: 2000 + (JD − 2451545) / 365.25).
    static func seconds(decimalYear y: Double) -> Double {
        let first = Double(DeltaTTable.firstYear)
        let last = Double(DeltaTTable.lastYear)
        let table = DeltaTTable.seconds

        if y < first {
            // Shift using the polynomial piece that applies below the table.
            return espenakMeeus(decimalYear: y) + (table[0] - espenakMeeus(decimalYear: first.nextDown))
        }
        if y >= last {
            return espenakMeeus(decimalYear: y) + (table[table.count - 1] - espenakMeeus(decimalYear: last))
        }
        let offset = y - first
        let i = Int(offset)
        let fraction = offset - Double(i)
        return table[i] + (table[i + 1] - table[i]) * fraction
    }

    /// Espenak–Meeus polynomial ΔT in seconds, unshifted.
    ///
    /// The Canon defines `y = year + (month − 0.5) / 12`; a continuous decimal
    /// year is equivalent to well under a second.
    static func espenakMeeus(decimalYear y: Double) -> Double {
        switch y {
        case ..<(-500):
            let u = (y - 1820) / 100
            return -20 + 32 * u * u
        case ..<500:
            let u = y / 100
            return polynomial(
                u,
                [10583.6, -1014.41, 33.78311, -5.952053, -0.1798452, 0.022174192, 0.0090316521]
            )
        case ..<1600:
            let u = (y - 1000) / 100
            return polynomial(
                u,
                [1574.2, -556.01, 71.23472, 0.319781, -0.8503463, -0.005050998, 0.0083572073]
            )
        case ..<1700:
            let t = y - 1600
            return polynomial(t, [120, -0.9808, -0.01532, 1.0 / 7129])
        case ..<1800:
            let t = y - 1700
            return polynomial(t, [8.83, 0.1603, -0.0059285, 0.00013336, -1.0 / 1_174_000])
        case ..<1860:
            let t = y - 1800
            return polynomial(
                t,
                [
                    13.72, -0.332447, 0.0068612, 0.0041116, -0.00037436,
                    0.0000121272, -0.0000001699, 0.000000000875,
                ]
            )
        case ..<1900:
            let t = y - 1860
            return polynomial(t, [7.62, 0.5737, -0.251754, 0.01680668, -0.0004473624, 1.0 / 233_174])
        case ..<1920:
            let t = y - 1900
            return polynomial(t, [-2.79, 1.494119, -0.0598939, 0.0061966, -0.000197])
        case ..<1941:
            let t = y - 1920
            return polynomial(t, [21.20, 0.84493, -0.076100, 0.0020936])
        case ..<1961:
            let t = y - 1950
            return polynomial(t, [29.07, 0.407, -1.0 / 233, 1.0 / 2547])
        case ..<1986:
            let t = y - 1975
            return polynomial(t, [45.45, 1.067, -1.0 / 260, -1.0 / 718])
        case ..<2005:
            let t = y - 2000
            return polynomial(
                t,
                [63.86, 0.3345, -0.060374, 0.0017275, 0.000651814, 0.00002373599]
            )
        case ..<2050:
            let t = y - 2000
            return polynomial(t, [62.92, 0.32217, 0.005589])
        case ..<2150:
            let u = (y - 1820) / 100
            return -20 + 32 * u * u - 0.5628 * (2150 - y)
        default:
            let u = (y - 1820) / 100
            return -20 + 32 * u * u
        }
    }

    /// Horner evaluation of c₀ + c₁x + c₂x² + …
    private static func polynomial(_ x: Double, _ coefficients: [Double]) -> Double {
        coefficients.reversed().reduce(0) { $0 * x + $1 }
    }
}

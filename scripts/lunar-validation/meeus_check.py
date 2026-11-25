"""Compare Meeus ch. 49 new moon times and ch. 48 low-precision illumination
against JPL DE440s via Skyfield.

Supports ADR 3 (doc/architecture/decisions/0003-source-of-truth-for-lunar-calculations.md).
See README.md in this folder for how to run it.

Usage: python meeus_check.py [path/to/de440s.bsp]
Without a path, Skyfield downloads de440s.bsp (~32 MB) from JPL into the
current directory, or reuses it if it is already there.
"""
import sys
from math import sin, cos, radians, degrees
import numpy as np
from skyfield.api import load
from skyfield import almanac

EPH = sys.argv[1] if len(sys.argv) > 1 else "de440s.bsp"


def meeus_new_moon_jde(k):
    T = k / 1236.85
    jde = (2451550.09766 + 29.530588861 * k + 0.00015437 * T**2
           - 0.000000150 * T**3 + 0.00000000073 * T**4)
    E = 1 - 0.002516 * T - 0.0000074 * T**2
    M = radians(2.5534 + 29.10535670 * k - 0.0000014 * T**2 - 0.00000011 * T**3)
    Mp = radians(201.5643 + 385.81693528 * k + 0.0107582 * T**2
                 + 0.00001238 * T**3 - 0.000000058 * T**4)
    F = radians(160.7108 + 390.67050284 * k - 0.0016118 * T**2
                - 0.00000227 * T**3 + 0.000000011 * T**4)
    Om = radians(124.7746 - 1.56375588 * k + 0.0020672 * T**2 + 0.00000215 * T**3)
    c = (-0.40720 * sin(Mp)
         + 0.17241 * E * sin(M)
         + 0.01608 * sin(2 * Mp)
         + 0.01039 * sin(2 * F)
         + 0.00739 * E * sin(Mp - M)
         - 0.00514 * E * sin(Mp + M)
         + 0.00208 * E * E * sin(2 * M)
         - 0.00111 * sin(Mp - 2 * F)
         - 0.00057 * sin(Mp + 2 * F)
         + 0.00056 * E * sin(2 * Mp + M)
         - 0.00042 * sin(3 * Mp)
         + 0.00042 * E * sin(M + 2 * F)
         + 0.00038 * E * sin(M - 2 * F)
         - 0.00024 * E * sin(2 * Mp - M)
         - 0.00017 * sin(Om)
         - 0.00007 * sin(Mp + 2 * M)
         + 0.00004 * sin(2 * Mp - 2 * F)
         + 0.00004 * sin(3 * M)
         + 0.00003 * sin(Mp + M - 2 * F)
         + 0.00003 * sin(2 * Mp + 2 * F)
         - 0.00003 * sin(Mp + M + 2 * F)
         + 0.00003 * sin(Mp - M + 2 * F)
         - 0.00002 * sin(Mp - M - 2 * F)
         - 0.00002 * sin(3 * Mp + M)
         + 0.00002 * sin(4 * Mp))
    A = [299.77 + 0.107408 * k - 0.009173 * T**2,
         251.88 + 0.016321 * k, 251.83 + 26.651886 * k, 349.42 + 36.412478 * k,
         84.66 + 18.206239 * k, 141.74 + 53.303771 * k, 207.14 + 2.453732 * k,
         154.84 + 7.306860 * k, 34.52 + 27.261239 * k, 207.19 + 0.121824 * k,
         291.34 + 1.844379 * k, 161.72 + 24.198154 * k, 239.56 + 25.513099 * k,
         331.55 + 3.592518 * k]
    W = [325, 165, 164, 126, 110, 62, 60, 56, 47, 42, 40, 37, 35, 23]
    add = sum(w * 1e-6 * sin(radians(a)) for w, a in zip(W, A))
    return jde + c + add


def meeus_illum_low(jde):
    T = (jde - 2451545.0) / 36525
    D = 297.8501921 + 445267.1114034 * T - 0.0018819 * T**2 + T**3 / 545868 - T**4 / 113065000
    M = 357.5291092 + 35999.0502909 * T - 0.0001536 * T**2 + T**3 / 24490000
    Mp = 134.9633964 + 477198.8675055 * T + 0.0087414 * T**2 + T**3 / 69699 - T**4 / 14712000
    D, M, Mp = (radians(x % 360) for x in (D, M, Mp))
    i = (180 - degrees(D) - 6.289 * sin(Mp) + 2.100 * sin(M) - 1.274 * sin(2 * D - Mp)
         - 0.658 * sin(2 * D) - 0.214 * sin(2 * Mp) - 0.110 * sin(D))
    return (1 + cos(radians(i))) / 2


# Sanity check: Meeus Example 49.a, new moon of 1977 Feb, k = -283
ex = meeus_new_moon_jde(-283)
print(f"Example 49.a: {ex:.5f} (book 2443192.65118), diff {(ex - 2443192.65118) * 86400:.1f} s")

ts = load.timescale()
eph = load(EPH)

# True new moons from DE440s, 1900-2100, in TT
t0, t1 = ts.utc(1900, 1, 1), ts.utc(2100, 12, 31)
times, phases = almanac.find_discrete(t0, t1, almanac.moon_phases(eph))
nm = times[phases == 0]
print(f"DE440s new moons 1900-2100: {len(nm)}")

errs, years = [], []
for t in nm:
    k = round((t.tt - 2451550.09766) / 29.530588861)
    errs.append((meeus_new_moon_jde(k) - t.tt) * 86400)
    years.append(t.utc.year)
errs, years = np.array(errs), np.array(years)


def report(mask, label):
    e = np.abs(errs[mask])
    print(f"  {label:10s} n={mask.sum():4d}  mean |err| {e.mean():5.1f} s  "
          f"RMS {np.sqrt((errs[mask]**2).mean()):5.1f} s  max {e.max():5.1f} s")


print("Meeus ch. 49 vs DE440s, TT vs TT (no Delta T involved):")
report(years >= 1900, "1900-2100")
report((years >= 1980) & (years <= 2020), "1980-2020")
report((years >= 2000) & (years <= 2050), "2000-2050")
report(years < 1950, "1900-1949")
report(years > 2050, "2051-2100")

# Delta T: what a constant 69 s does vs Skyfield's Delta T model
dt = np.array([t.delta_t for t in nm])
for lo, hi in [(1900, 1950), (1950, 2000), (2000, 2026), (2026, 2050), (2050, 2101)]:
    m = (years >= lo) & (years < hi)
    print(f"  Delta T {lo}-{hi - 1}: {dt[m].min():6.1f} .. {dt[m].max():6.1f} s")

# Ch. 48 low-precision illumination vs DE440s geocentric fraction illuminated
rng = np.random.default_rng(1)
jd = rng.uniform(ts.utc(1900).tt, ts.utc(2100).tt, 5000)
tt = ts.tt_jd(jd)
earth, sun, moon = eph["earth"], eph["sun"], eph["moon"]
true_k = earth.at(tt).observe(moon).apparent().fraction_illuminated(sun)
meeus_k = np.array([meeus_illum_low(j) for j in jd])
d = (meeus_k - true_k) * 100
print("Meeus ch. 48 low-precision illumination vs DE440s (5000 random instants 1900-2100):")
print(f"  mean |err| {np.abs(d).mean():.3f} pp  max {np.abs(d).max():.3f} pp  "
      f"rounded whole % differs in {np.mean(np.round(meeus_k * 100) != np.round(true_k * 100)) * 100:.1f}% of samples")

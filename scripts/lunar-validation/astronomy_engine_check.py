"""Compare Astronomy Engine new moon times and illumination against JPL DE440s
via Skyfield.

Supports ADR 3 (doc/architecture/decisions/0003-source-of-truth-for-lunar-calculations.md),
Option A. Uses the `astronomy-engine` Python package, which is generated from
the same source as the C library used on the feature/astro branch.
See README.md in this folder for how to run it.

Usage: python astronomy_engine_check.py [path/to/de440s.bsp]
Without a path, Skyfield downloads de440s.bsp (~32 MB) from JPL into the
current directory, or reuses it if it is already there.
"""
import sys
import numpy as np
import astronomy
from skyfield.api import load
from skyfield import almanac
from skyfield.framelib import ecliptic_frame
from skyfield.searchlib import find_discrete

EPH = sys.argv[1] if len(sys.argv) > 1 else "de440s.bsp"
J2000 = 2451545.0

ts = load.timescale()
eph = load(EPH)

# True new moons from DE440s, 1900-2100
t0, t1 = ts.utc(1900, 1, 1), ts.utc(2100, 12, 31)
times, phases = almanac.find_discrete(t0, t1, almanac.moon_phases(eph))
nm = times[phases == 0]
print(f"DE440s new moons 1900-2100: {len(nm)}")

# Astronomy Engine: search for each new moon starting a day before DE440s's.
tt_err, ut_err, years = [], [], []
for t in nm:
    start = astronomy.Time(t.ut1 - J2000 - 1.0)
    ae = astronomy.SearchMoonPhase(0.0, start, 3.0)
    tt_err.append(((ae.tt + J2000) - t.tt) * 86400)
    # UT: Astronomy Engine's own Delta T model vs Skyfield's (UT1)
    ut_err.append(((ae.ut + J2000) - t.ut1) * 86400)
    years.append(t.utc.year)
tt_err, ut_err, years = np.array(tt_err), np.array(ut_err), np.array(years)


def report(errs, mask, label):
    e = np.abs(errs[mask])
    print(f"  {label:10s} n={mask.sum():4d}  mean |err| {e.mean():5.1f} s  "
          f"RMS {np.sqrt((errs[mask]**2).mean()):5.1f} s  max {e.max():5.1f} s")


ranges = [((years >= 1900), "1900-2100"),
          ((years >= 1980) & (years <= 2020), "1980-2020"),
          ((years >= 2000) & (years <= 2050), "2000-2050"),
          ((years < 1950), "1900-1949"),
          ((years > 2050), "2051-2100")]

print("Astronomy Engine vs DE440s, TT vs TT (ephemeris error only):")
for m, label in ranges:
    report(tt_err, m, label)
print(f"  signed mean {tt_err.mean():+.1f} s, range {tt_err.min():+.1f} .. {tt_err.max():+.1f} s "
      "(positive = Astronomy Engine later)")


# Where the bias comes from: the standard new moon (Skyfield, USNO, Meeus) uses
# apparent positions. Redo the DE440s search with purely geometric positions
# (no light-time or aberration) and compare Astronomy Engine with that.
def geometric_quarter(t):
    _, sl, _ = (eph["sun"] - eph["earth"]).at(t).frame_latlon(ecliptic_frame)
    _, ml, _ = (eph["moon"] - eph["earth"]).at(t).frame_latlon(ecliptic_frame)
    return ((ml.degrees - sl.degrees) % 360.0 // 90).astype(int)


geometric_quarter.step_days = 7
gtimes, gphases = find_discrete(t0, t1, geometric_quarter)
gnm = gtimes[gphases == 0]
n = min(len(gnm), len(nm))
geo_shift = np.array([(gnm[i].tt - nm[i].tt) * 86400 for i in range(n)])
ae_vs_geo = tt_err[:n] - geo_shift
print("Geometric new moon (DE440s, no light-time/aberration) vs apparent new moon:")
print(f"  mean shift {geo_shift.mean():+.1f} s")
print(f"Astronomy Engine vs geometric new moon: mean {ae_vs_geo.mean():+.1f} s, "
      f"max |err| {np.abs(ae_vs_geo).max():.1f} s")
print("Astronomy Engine vs DE440s, UT vs UT1 (adds the difference in Delta T models):")
for m, label in ranges:
    report(ut_err, m, label)

# Illumination at random instants vs DE440s geocentric fraction illuminated
rng = np.random.default_rng(1)
jd = rng.uniform(ts.utc(1900).tt, ts.utc(2100).tt, 5000)
tt = ts.tt_jd(jd)
earth, sun, moon = eph["earth"], eph["sun"], eph["moon"]
true_k = earth.at(tt).observe(moon).apparent().fraction_illuminated(sun)
ae_k = np.array([astronomy.Illumination(astronomy.Body.Moon,
                                        astronomy.Time.FromTerrestrialTime(j - J2000)).phase_fraction
                 for j in jd])
d = (ae_k - true_k) * 100
print("Astronomy Engine illumination vs DE440s (5000 random instants 1900-2100):")
print(f"  mean |err| {np.abs(d).mean():.3f} pp  max {np.abs(d).max():.3f} pp  "
      f"rounded whole % differs in {np.mean(np.round(ae_k * 100) != np.round(true_k * 100)) * 100:.1f}% of samples")

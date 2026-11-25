"""Generate the reference fixture that SwiftMoon's tests check Meeus against.

ADR 3 (Option C as test oracle): every true new moon 1900-2100 from JPL DE440s
via Skyfield, plus a seeded sample of illuminated fraction and phase
elongation. The output is committed at
Tests/SwiftMoonTests/Fixtures/new_moons_de440s.json.

Usage (from the repository root):
    python scripts/lunar-validation/generate_fixture.py [path/to/de440s.bsp]

Without a path, Skyfield downloads de440s.bsp (~32 MB) from JPL into the
current directory, or reuses it if it is already there. Don't commit the .bsp.

Regenerating with newer Skyfield/IERS data can move UT1 times near 2100 by
seconds (Delta T there is a prediction). TT times depend only on the ephemeris.
"""
import datetime
import hashlib
import json
import os
import sys

import numpy as np
import skyfield
from skyfield import almanac
from skyfield.api import load

EPH = sys.argv[1] if len(sys.argv) > 1 else "de440s.bsp"
OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "Tests", "SwiftMoonTests", "Fixtures", "new_moons_de440s.json",
)
UNIX_EPOCH_JD = 2440587.5
ILLUMINATION_SAMPLES = 500


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def unix(jd):
    return (jd - UNIX_EPOCH_JD) * 86400.0


ts = load.timescale()
eph = load(EPH)
eph_path = EPH if os.path.exists(EPH) else os.path.join(load.directory, EPH)

# True (apparent, geocentric) new moons 1900-2100, the same search as meeus_check.py.
t0, t1 = ts.utc(1900, 1, 1), ts.utc(2101, 1, 1)
times, phases = almanac.find_discrete(t0, t1, almanac.moon_phases(eph))
new_moons = times[phases == 0]

rows = []
for t in new_moons:
    # Meeus lunation number: k = 0 is the new moon of 2000 Jan 6.
    k = int(round((t.tt - 2451550.09766) / 29.530588861))
    rows.append({
        "k": k,
        "jdTT": round(float(t.tt), 8),
        "unixUT1": round(unix(float(t.ut1)), 3),
        "deltaT": round(float(t.delta_t), 3),
    })
ks = [r["k"] for r in rows]
assert ks == list(range(ks[0], ks[0] + len(ks))), "lunation numbers must be consecutive"

# Illuminated fraction and elongation at seeded random instants.
rng = np.random.default_rng(1)
jd = np.sort(rng.uniform(ts.utc(1900).tt, ts.utc(2100).tt, ILLUMINATION_SAMPLES))
tt = ts.tt_jd(jd)
earth, sun, moon = eph["earth"], eph["sun"], eph["moon"]
fraction = earth.at(tt).observe(moon).apparent().fraction_illuminated(sun)
elongation = almanac.moon_phase(eph, tt).degrees
samples = [
    {
        "jdTT": round(float(j), 8),
        "unixUT1": round(unix(float(u)), 3),
        "fraction": round(float(f), 6),
        "elongation": round(float(e), 4),
    }
    for j, u, f, e in zip(jd, tt.ut1, fraction, elongation)
]

meta = {
    "description": "Apparent geocentric new moons and Moon illumination from JPL DE440s, "
                   "for SwiftMoon fixture tests (ADR 3).",
    "generator": "scripts/lunar-validation/generate_fixture.py",
    "generated": datetime.date.today().isoformat(),
    "skyfield": skyfield.__version__,
    "numpy": np.__version__,
    "ephemeris": os.path.basename(EPH),
    "ephemerisSHA256": sha256(eph_path),
    "deltaT": "Skyfield built-in IERS/Morrison-Stephenson model (unixUT1 = UT1 seconds since 1970)",
    "range": "1900-01-01 .. 2101-01-01 UTC",
    "newMoonCount": len(rows),
}

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    # One entry per line keeps diffs reviewable.
    f.write("{\n")
    f.write(f'"meta": {json.dumps(meta, indent=1)},\n')
    f.write('"newMoons": [\n')
    f.write(",\n".join(json.dumps(r, separators=(",", ":")) for r in rows))
    f.write("\n],\n")
    f.write('"illumination": [\n')
    f.write(",\n".join(json.dumps(s, separators=(",", ":")) for s in samples))
    f.write("\n]\n}\n")

print(f"Wrote {len(rows)} new moons (k {ks[0]}..{ks[-1]}) and {len(samples)} "
      f"illumination samples to {os.path.relpath(OUT)}")

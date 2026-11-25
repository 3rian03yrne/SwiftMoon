# Lunar validation

These are development tools and are not part of the library. They support ADR 3 in the Penobscot Names of the Moons app repo (`doc/architecture/decisions/0003-source-of-truth-for-lunar-calculations.md`). They generate SwiftMoon's test fixture and ΔT table, and they check the two lunar calculation sources compared in the ADR against NASA JPL's DE440s ephemeris, using [Skyfield](https://rhodesmill.org/skyfield/): the Meeus algorithms (Option B) and Astronomy Engine (Option A, used on `feature/astro`).

`meeus_check.py` does four things:

1. Reproduces Meeus Example 49.a (the new moon of 1977 Feb, JDE 2443192.65118). This catches typos in the coefficients.
2. Finds every new moon in 1900–2100 in DE440s and compares each one with Meeus ch. 49. Both sides are in Terrestrial Time (TT), so ΔT has no effect on the result.
3. Prints the range of ΔT (TT − UT) for each period, so you can judge a constant-ΔT shortcut.
4. Compares the Meeus ch. 48 low-precision illuminated fraction with DE440s at 5,000 random instants.

`astronomy_engine_check.py` runs the same comparisons for Astronomy Engine. It uses the `astronomy-engine` Python package, which is generated from the same source as the C library. It also:

- compares UT times, which brings in Astronomy Engine's own ΔT model;
- repeats the DE440s search with geometric positions (no light-time or aberration), which explains Astronomy Engine's consistent late bias.

`generate_fixture.py` writes `Tests/SwiftMoonTests/Fixtures/new_moons_de440s.json`, the test oracle. It holds every DE440s new moon from 1900 to 2100 (Meeus k, JD in TT, UT1 Unix seconds and Skyfield's ΔT), plus 500 seeded illumination and elongation samples. Its `meta` block records the Skyfield and numpy versions and the SHA-256 of the ephemeris.

`generate_delta_t.py` writes `Sources/SwiftMoon/Meeus/DeltaTTable.swift`, the yearly ΔT table for 1900–2101 from Skyfield's built-in ΔT model. It needs no ephemeris. The table replaces the Espenak–Meeus polynomials inside that range, because their 2006 predictions run high: 5 s too high in 2025, 22 s in 2050 and 107 s in 2100. That broke the 1-minute UTC requirement after about 2060. Regenerate the table with a newer Skyfield to pick up new IERS data. Expect values after today to move by seconds.

## Run it

Run these commands from the repository root. They need Python 3.9 or later.

```bash
python3 -m venv .venv-lunar
```

```bash
.venv-lunar/bin/pip install -r scripts/lunar-validation/requirements.txt
```

```bash
.venv-lunar/bin/python scripts/lunar-validation/meeus_check.py
```

```bash
.venv-lunar/bin/python scripts/lunar-validation/astronomy_engine_check.py
```

```bash
.venv-lunar/bin/python scripts/lunar-validation/generate_fixture.py
```

```bash
.venv-lunar/bin/python scripts/lunar-validation/generate_delta_t.py
```

Without an argument, Skyfield downloads `de440s.bsp` (about 32 MB, covering 1849–2150) from JPL into the current directory. To reuse a copy you already have, pass its path as the first argument. Don't commit the `.bsp` file.

Each full 1900–2100 search takes a few minutes. After regenerating either file, run `swift test`.

## Results (2026-11-25, Skyfield 1.55, DE440s)

### `meeus_check.py`

```
Example 49.a: 2443192.65118 (book 2443192.65118), diff 0.2 s
DE440s new moons 1900-2100: 2487
Meeus ch. 49 vs DE440s, TT vs TT (no Delta T involved):
  1900-2100  n=2487  mean |err|   3.6 s  RMS   4.6 s  max  17.2 s
  1980-2020  n= 507  mean |err|   3.6 s  RMS   4.5 s  max  17.2 s
  2000-2050  n= 631  mean |err|   3.8 s  RMS   5.0 s  max  17.2 s
  1900-1949  n= 619  mean |err|   3.5 s  RMS   4.3 s  max  13.9 s
  2051-2100  n= 619  mean |err|   3.5 s  RMS   4.4 s  max  14.8 s
  Delta T 1900-1949:   -2.0 ..   28.9 s
  Delta T 1950-1999:   28.9 ..   63.8 s
  Delta T 2000-2025:   63.8 ..   69.4 s
  Delta T 2026-2049:   69.1 ..   71.4 s
  Delta T 2050-2100:   71.5 ..   96.7 s
Meeus ch. 48 low-precision illumination vs DE440s (5000 random instants 1900-2100):
  mean |err| 0.088 pp  max 0.329 pp  rounded whole % differs in 8.3% of samples
```

### `astronomy_engine_check.py` (astronomy-engine 2.1.19)

```
DE440s new moons 1900-2100: 2487
Astronomy Engine vs DE440s, TT vs TT (ephemeris error only):
  1900-2100  n=2487  mean |err|  38.5 s  RMS  38.7 s  max  50.9 s
  1980-2020  n= 507  mean |err|  39.2 s  RMS  39.4 s  max  50.7 s
  2000-2050  n= 631  mean |err|  39.8 s  RMS  40.0 s  max  50.2 s
  1900-1949  n= 619  mean |err|  36.7 s  RMS  36.9 s  max  47.9 s
  2051-2100  n= 619  mean |err|  38.9 s  RMS  39.2 s  max  50.0 s
  signed mean +38.5 s, range +25.9 .. +50.9 s (positive = Astronomy Engine later)
Geometric new moon (DE440s, no light-time/aberration) vs apparent new moon:
  mean shift +38.3 s
Astronomy Engine vs geometric new moon: mean +0.2 s, max |err| 7.6 s
Astronomy Engine vs DE440s, UT vs UT1 (adds the difference in Delta T models):
  1900-2100  n=2487  mean |err|  34.6 s  RMS  36.7 s  max  77.3 s
  1980-2020  n= 507  mean |err|  38.8 s  RMS  39.0 s  max  50.7 s
  2000-2050  n= 631  mean |err|  32.1 s  RMS  33.2 s  max  49.2 s
  1900-1949  n= 619  mean |err|  37.1 s  RMS  37.3 s  max  47.9 s
  2051-2100  n= 619  mean |err|  31.2 s  RMS  37.7 s  max  77.3 s
Astronomy Engine illumination vs DE440s (5000 random instants 1900-2100):
  mean |err| 0.000 pp  max 0.001 pp  rounded whole % differs in 0.0% of samples
```

ΔT values after 2026 are Skyfield's predictions, so they will change as new IERS data comes in.

### Swift implementation (`swift test`, 2026-11-25)

```
Meeus ch. 49 vs DE440s (TT): n = 2487, mean |err| 3.6 s, max 17.2 s
Meeus ch. 49 + ΔT vs DE440s (UT): max 17.2 s
Meeus ch. 48 illumination vs DE440s: max 0.310 pp
ΔT table vs Skyfield: max 0.09 s
```

The Swift TT figures match `meeus_check.py` exactly, which confirms the transcription.

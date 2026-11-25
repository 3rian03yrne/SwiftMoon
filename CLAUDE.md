# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Commands

```bash
swift build
swift test
swift test --filter MoonPhasesTests   # one suite
```

## What this is

A pure-Swift library for Moon phases: true new moon instants, lunations, illumination, phase and age. It is the source of truth for lunar math in the Penobscot Names of the Moons app (ADR 3 in that app's repo, `doc/architecture/decisions/0003-source-of-truth-for-lunar-calculations.md`). There are no dependencies and no C, and every public type is `Sendable`.

## Layout

- `Sources/SwiftMoon/SwiftMoon.swift`: the whole public API, plus the `LunationPeriod` and `MoonIllumination` value types and the deprecated 1.x shims.
- `Sources/SwiftMoon/Meeus/` (internal):
  - `MoonPhases.swift`: Meeus ch. 49 true new moon (`newMoonJDE(k:)`, in TT) and `lunationNumber(containing:)`.
  - `Illumination.swift`: Meeus ch. 48 low-precision illuminated fraction and signed phase angle.
  - `JulianDay.swift`: Date ↔ JD and JDE. It works from Unix seconds and never uses `Calendar`.
  - `DeltaT.swift`: ΔT. Inside 1900–2101 it interpolates `DeltaTTable`; outside, it uses the Espenak–Meeus polynomials shifted to join the table.
  - `DeltaTTable.swift`: **generated**, don't edit by hand.
- `Tests/SwiftMoonTests/Fixtures/new_moons_de440s.json`: the **generated** DE440s oracle.
- `scripts/lunar-validation/`: Python and Skyfield dev tools that generate the fixture and ΔT table and run the accuracy studies.

## Rules

- **Coefficients.** Cite Meeus by chapter and equation. Don't copy from LGPL ports such as PyMeeus. `MoonPhases.swift` mirrors `scripts/lunar-validation/meeus_check.py` term for term, so keep the two in step.
- **Fixture tolerances.** These are deliberate and must not be loosened to make a change pass:
  - new moons ≤ 30 s in TT (measured max 17.2 s);
  - ≤ 60 s in UTC (the requirement);
  - illumination < 0.5 pp.
- **Lunation boundaries.** Start inclusive, end exclusive. Meeus k = 0 is the new moon of 2000 Jan 6, and 1.x used the same numbering.
- **Penobscot rule.** `lunationIndex(for:calendar:)` is the one place the month-boundary rule lives: new moons at or before the date since Jan 1 00:00 in the calendar's zone. The app owns the names, the wrap of index 0 across the year boundary, and the display strings.
- **Age.** Elapsed time is a plain `TimeInterval`. Never use `Calendar.current` for it.

# SwiftMoon

SwiftMoon is a pure-Swift package for the Moon's phases: exact new moon instants, lunations, illuminated fraction, phase and the Moon's age. It has no dependencies and no C, works offline, and every public type is `Sendable`.

## Accuracy

The calculations follow Jean Meeus, *Astronomical Algorithms* (2nd ed.). They have been measured against NASA JPL's DE440s ephemeris over 1900–2100:

| | Mean error | Maximum error |
|---|---|---|
| New moon instants (ch. 49), TT | 3.6 s | 17.2 s |
| New moon instants, UTC | | 17.2 s |
| Illuminated fraction (ch. 48, low precision) | 0.09 pp | 0.31 pp |
| Phase elongation | | < 1.5° |

Converting from Terrestrial Time to UTC needs ΔT. For 1900–2101, SwiftMoon interpolates a yearly ΔT table generated from [Skyfield](https://rhodesmill.org/skyfield/). Outside that range it uses the Espenak–Meeus polynomials. ΔT values after today are predictions, so future instants may move by a few seconds as Earth's rotation is measured.

## Installation

```swift
.package(url: "https://github.com/3rianO3yrne/SwiftMoon.git", from: "2.0.0")
```

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "SwiftMoon", package: "SwiftMoon")
    ]
)
```

## Usage

```swift
import SwiftMoon

let now = Date()

// The lunation (new moon to next new moon) containing a date.
let lunation = SwiftMoon.lunation(containing: now)
lunation.lunationNumber      // Meeus k: 0 = the new moon of 2000 Jan 6
lunation.lunationStartDate   // this lunation's new moon (inclusive)
lunation.lunationEndDate     // the next new moon (exclusive)

// Time since the new moon, as a plain interval (DST has no effect).
let age = SwiftMoon.age(at: now)

// Illumination and phase.
let moon = SwiftMoon.illumination(at: now)
moon.fraction     // 0…1
moon.elongation   // 0 new, 90 first quarter, 180 full, 270 last quarter
moon.isWaxing

// New moons in a range, or in a calendar year in a time zone.
SwiftMoon.newMoons(from: start, to: end)
SwiftMoon.newMoons(inYearContaining: now, calendar: .current)

// Index of the current moon in its year: new moons at or before the date
// since Jan 1 00:00 in the calendar's time zone (12 or 13 per year).
let (index, count) = SwiftMoon.lunationIndex(for: now, calendar: .current)
```

### Migrating from 1.x

SwiftMoon 1.x stepped a *mean* synodic month from an epoch, which could be up to about 14 hours off. 2.0 uses true new moons. Lunation numbers are unchanged (lunation 0 is still the new moon of 2000 Jan 6), but lunation start and end dates move to the true instants.

- `getMoonForDate(date:)` and `getLunationPeriod(date:)` are deprecated. Use `lunation(containing:)`.
- `getLunationPeriods(date:)` is deprecated. Use `lunation(containing:)` or `lunation(number:)`.
- The mean-month helpers on `LunationPeriod` (`getLunarMonthPeriodDateComponents` and the rest) have been removed.

## Requirements

- Swift 6.0 or later
- macOS 10.15 or later, iOS 13 or later

## Running tests

```sh
swift test
```

The tests compare every new moon from 1900 to 2100 with a committed DE440s fixture. To regenerate the fixture or the ΔT table, see [scripts/lunar-validation/README.md](scripts/lunar-validation/README.md).

## License

This project is licensed under the terms of the MIT license. See [LICENSE.md](LICENSE.md) for details.

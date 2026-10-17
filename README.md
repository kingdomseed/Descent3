# Descent 3 Revival

A native Apple version of Descent 3, translated from the GPL-released C++ source into Swift 6.4 and Metal 4. You need your own retail copy of the game. A one-way importer converts it into Revival's content format.

**Status:** Pilot Training plays to completion on Mac through the general game runtime. Campaign systems are in progress. See [the plan](docs/revival/plan.md).

## Build

Requires Xcode 27 and an Apple silicon Mac. The apps run on macOS 26 or later.

```bash
xcodebuild -project Revival.xcodeproj -scheme RevivalMac -configuration Release \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
```

Tests, import, and more: [docs/revival/engineering.md](docs/revival/engineering.md).

## Documentation

| Doc | Contents |
|---|---|
| [product.md](docs/revival/product.md) | What 1.0 is, what comes after, and the non-goals |
| [plan.md](docs/revival/plan.md) | Current state, milestones, next work, and the level checklist |
| [architecture.md](docs/revival/architecture.md) | Modules, `GameWorld`, frame order, the script runtime, saves, and intentional differences |
| [engineering.md](docs/revival/engineering.md) | Toolchain, build and test, the work loop, review, and cleanup |
| [sources.md](docs/revival/sources.md) | Source pins, fork corrections, retail data, and rights |
| [history.md](docs/revival/history.md) | The first attempt (July–August 2026), and where the old docs went |
| [AGENTS.md](AGENTS.md) | Rules for AI agents |

## Repository layout

- `Revival/`, `Revival.xcodeproj`: the Swift products (D3Import, RevivalMac, RevivalMobile, RevivalEditor).
- The other top-level folders (`Descent3/`, `physics/`, `scripts/`, and so on): the pinned [DescentDevelopers/Descent3](https://github.com/DescentDevelopers/Descent3) C++ tree at `156cba8a`. This is the translation source. It is not linked into the Swift products. Its own docs are [BUILD.md](BUILD.md), [USAGE.md](USAGE.md), and [CHANGELOG.md](CHANGELOG.md).

## Retail content

No game data is included. Retail and converted content stays out of Git. See [sources.md](docs/revival/sources.md).

## License

GPL-3.0-or-later, as the released source. Translated code keeps that license. Retail media keeps its original ownership. See [THIRD_PARTY.md](THIRD_PARTY.md).

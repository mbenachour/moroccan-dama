# Dama — Moroccan Checkers

An iOS game of **Moroccan checkers (dama / ضامة)**: the North African branch
of the Spanish draughts family, played in cafés across Morocco, Algeria and
Tunisia — traditionally with bottle caps on a hand-drawn board.

No account, no sign-in. The app opens straight into a game: **you (White)
against the computer**, in three difficulties. Online multiplayer is a
planned future version; v1 is deliberately single-device.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)

## The Moroccan rules (as implemented)

| Rule | Moroccan dama |
| --- | --- |
| Board | 8×8, **mirrored** — the double corner is on each player's left, the near-left corner square is light |
| Pieces | 12 per side, on the dark squares of the three home rows |
| First move | White |
| Men | Move and capture one square diagonally **forward only** — no backward captures |
| Captures | **Mandatory**, and you must take the line capturing the **most pieces** (ties: any longest line — no Spanish most-kings tiebreak) |
| Multi-captures | Chain in a single turn; captured pieces are removed only when the move ends, so no piece can be jumped twice |
| Crowning | A man reaching the far row is crowned and the move **stops** — it does not continue capturing as a king that turn |
| Kings (*dama*) | **Flying**: move and capture any distance along a diagonal, landing on any empty square beyond the captured piece |
| Win | Capture all opponent pieces, or block them so they have no legal move |
| Draw | Threefold repetition, or 40 moves by each side with no capture and no man moving |

Not to confuse with **Turkish dama** (16 pieces, orthogonal moves, all 64
squares) — a completely different game that shares the name.

The rules live in a standalone Swift package, [`Packages/DamaEngine`](Packages/DamaEngine),
with a unit test for every rule above. The app is a thin SwiftUI layer on top.

## Project layout

```
MoroccanDama.xcodeproj        The iOS app project (Xcode 16+, folder-synchronized)
MoroccanDama/                 SwiftUI app: board view, game view model, rules sheet
Packages/DamaEngine/          Pure-Swift rules engine + AI opponent + XCTest suite
.github/workflows/ci.yml      Engine tests + unsigned app build on every push/PR
.github/workflows/release.yml Manual/tag release build: simulator app + unsigned device archive
```

## Build & run

**Requirements:** macOS with Xcode 16 or later.

```sh
git clone https://github.com/mbenachour/moroccan-dama.git
cd moroccan-dama
open MoroccanDama.xcodeproj
```

Pick an iPhone simulator and Run. No signing is needed for the simulator.

**Engine tests** (also run in CI):

```sh
swift test --package-path Packages/DamaEngine
```

## Shipping (when you're ready)

CI builds are unsigned, so no Apple Developer account is needed to develop.
To put the app on a real device or TestFlight:

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/).
2. In Xcode, select the **MoroccanDama** target → *Signing & Capabilities* →
   tick *Automatically manage signing* and choose your team.
   (Bundle ID is `net.mohamedbenachour.moroccandama`; register it in your
   developer account if Xcode asks.)
3. Product → Archive, then distribute via the Organizer (TestFlight / App Store).
   Signing secrets for fully automated releases can be wired into
   `release.yml` at that point.

## Roadmap

- [x] v1 — Player vs computer (3 difficulties), full Moroccan rules engine
- [ ] Café Mode: traditional street rules as toggles — *Nefkh* (huffing),
      *Yeddak 3la lbidaq* (touch-move), *Koul* (insist on capture)
- [ ] 2-player on one device
- [ ] Online multiplayer (Game Center)
- [ ] Arabic / French localization

## License

MIT — see [LICENSE](LICENSE).

# App Store submission packet — Dama (Moroccan Checkers)

Prepared 2026-10-19. Everything here is drafted and ready to paste into
App Store Connect on enrollment day. Items marked **[you]** need the
account holder; everything else is done or copy-paste.

## Readiness checklist

| Requirement | Status |
| --- | --- |
| Apple Developer Program enrollment ($99/yr) | **[you]** — the only hard blocker |
| Bundle ID `net.mohamedbenachour.moroccandama` | Set in project; register it in App Store Connect / Certificates portal |
| Code signing (team) | **[you]** — Xcode: target → Signing & Capabilities → pick your team |
| App icon 1024×1024, no alpha channel | ✅ Done (`AppIcon-1024.png`, RGB) |
| Launch screen | ✅ Done |
| Version / build | ✅ 1.0 (1) |
| Export compliance | ✅ Done — `ITSAppUsesNonExemptEncryption = NO` (app uses no non-exempt encryption), so App Store Connect won't hold the build for this questionnaire |
| Works without an account | ✅ No sign-in exists — nothing for review to get stuck on, and no Sign in with Apple obligation |
| Privacy — data collection | App collects **no data** (no analytics, no ads, no network calls). Answer "No, we do not collect data from this app" |
| Privacy policy URL | Draft below — publish it at `https://mbenachour.github.io/dama-privacy.html` (or any page on mohamedbenachour.net) and paste that URL |
| Support URL | `https://mbenachour.github.io/` (or mohamedbenachour.net) |
| Age rating questionnaire | All "None" → **4+** |
| Screenshots | **[Mac, 10 min]** — from Xcode Simulator, sizes below |
| App name uniqueness | Check at creation; if "Dama" collides, first fallback below |

**TestFlight vs App Store:** internal TestFlight needs none of the metadata
below — enroll, sign, upload, and internal testers can play the same day.
The public listing (this packet) is only for the App Store release.

## Listing copy (paste-ready)

- **Name (30 max):** `Dama — Moroccan Checkers` (24)
  Fallbacks: `Dama Maroc — Checkers`, `Moroccan Dama`
- **Subtitle (30 max):** `The café game of Morocco` (24)
- **Primary category:** Games → Board
- **Secondary category:** Games → Strategy
- **Price:** Free
- **Keywords (100 max):** `checkers,draughts,morocco,maghrib,board game,strategy,offline,flying kings,damme` (81)
- **Promotional text (170 max):** `The checkers of Moroccan cafés, on your iPhone: flying kings, forced captures, and the longest-line rule. No account — open it and play.`

**Description:**

> Dama is the checkers played across Morocco, Algeria and Tunisia — in cafés,
> with bottle caps on a hand-drawn board. This is that game, faithfully:
>
> • The mirrored Moroccan board — double corner on your left
> • Men capture forward only; crowning stops the move
> • Captures are mandatory, and you must take the longest line
> • Flying kings (a crowned piece is a dama) that sweep the diagonals
> • Draws by threefold repetition or the 40-move rule
>
> Play against the computer in three difficulties — a quick game on Easy, a
> real fight on Hard. No account, no ads, no tracking: open the app and your
> first move is waiting.
>
> Not Turkish dama, not American checkers — the North African game, with its
> own rules and its own tempo.

## App Review notes (paste into "Notes" for the reviewer)

> No account or sign-in is required; the app opens directly into a game.
> You play White (bottom). Tap one of your pieces, then tap a highlighted
> square to move. Captures are mandatory in Moroccan dama and the app only
> offers legal moves, including the longest capture line. The computer
> opponent ("Dama") replies automatically. "New game" and "Take back" are
> below the board; the (?) button explains the rules. The app makes no
> network calls and collects no data.

## Privacy policy (publish verbatim)

> **Privacy Policy — Dama (Moroccan Checkers)**
> Last updated: [date]
>
> Dama does not collect, store, transmit, or share any personal data. The app
> contains no accounts, no analytics, no advertising, and no third-party
> tracking, and it makes no network connections. Your games exist only on
> your device.
>
> If you contact us by email, we will only use your message to respond.
>
> Contact: me@mohamedbenachour.net

## Screenshots to capture (Simulator: ⌘S)

Required sizes for this app (iPhone + iPad support):

- iPhone 6.9" — 1320 × 2868 (portrait)
- iPad 13" — 2064 × 2752 (portrait)

Shots to take (3–5): (1) opening board, (2) mid-game with a piece selected
and destinations highlighted, (3) a capture about to happen on Hard,
(4) the "How to play" rules sheet, (5) a win state.

## Enrollment-day sequence

1. **[you]** Enroll at developer.apple.com/programs ($99/yr) and tell me it's active.
2. Create the app in App Store Connect (My Apps → +) with the bundle ID above.
3. Xcode: set your team on the MoroccanDama target (automatic signing).
4. Product → Archive → Distribute → App Store Connect → Upload.
   (Or hand me the signing material and I'll wire the release workflow to upload from CI.)
5. Paste the listing copy above, upload screenshots, set privacy answers.
6. Submit for review. Simple games are commonly reviewed within a day or
   two — that's Apple's queue, not a promise. TestFlight internal testing
   is available right after step 4, before review.

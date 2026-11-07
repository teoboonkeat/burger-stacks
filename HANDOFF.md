# Handoff: Jelly Beans

Read this first when you pick up development, on a local computer or in a
Claude Code cloud session. Last updated 2026-11-06.

## What it is

Jelly Beans (working title) is a casual jelly bean sort puzzle in Flutter + Flame,
built for Android. Players pour beans between tubes until every tube holds one
flavour. It has 200 levels, stars, sweets (the soft currency), boosters, a guided
tutorial and simulated ads/IAP. The code map is in `README.md`.

## Branches

- `main` is the source of truth and the GitHub default branch. Start new
  work from it.
- `claude/eloquent-lamport-nsm5ki` was the cloud dev branch. It is behind
  `main` now; delete it rather than building on it.
- Every push to any branch builds a release APK in GitHub Actions
  (`.github/workflows/build-apk.yml`) and publishes it as a `build-N`
  prerelease. Only the newest 3 are kept.

## Set up locally

You need Flutter stable (it was developed on 3.47.x, Dart SDK `^3.13.7`). For
APKs you also need the Android SDK. Run these from the repo root:

```bash
git clone https://github.com/teoboonkeat/burger-stacks.git && cd burger-stacks
```

```bash
flutter pub get
```

```bash
flutter test
```

```bash
flutter run
```

```bash
flutter build web --release
```

```bash
flutter build apk --release
```

All tests should pass, and `flutter analyze` should be clean. `flutter run` targets a connected phone or emulator,
or Chrome with `-d chrome`.

## Continue in a Claude Code cloud session

Open a session on `teoboonkeat/burger-stacks` and tell it to branch from `main`.
The cloud container already has Flutter at `/opt/flutter/bin/flutter`. You can
also run the skills below locally with the Claude Code CLI, since they are
committed in `.claude/`.

## Claude skills and agents (`.claude/`)

| Skill / agent | What it does |
|---|---|
| `play-test` / `play-tester` | Builds the web version, plays it in headless Chromium, and reports bugs, feel, difficulty and phone layout. Start the server with `bash .claude/skills/play-test/scripts/serve.sh <repo> <port>`. The script is not executable, so call it with `bash`. |
| `ui-design` / `ui-designer` | UI/UX audits, tutorial, splash, icon, Play Store assets. It works in two phases, propose (a mockup page) and then build. |
| `game-design` / `game-designer` | Progression, meta-game, economy, retention and difficulty pacing. It works in two phases, propose (a proposal page) and then build. |

## Rules that must keep holding

- **Save format:** add new keys only. Never rename or remove a key, so
  existing players keep their progress.
- **Par equals the solver optimum** for every level (`lib/logic/solver.dart`).
  `test/levels_test.dart` checks this, along with the 200-level count, the
  bean multiset for each level, and the level-28 soft-dead-end case.
- **Stars** (`starsFor` in `lib/logic/board.dart`):
  - ★★★ when moves ≤ par.
  - ★★ when moves ≤ max(floor(par × 1.2), par + 1).
  - Otherwise ★.
- **Undo** refunds the move it undoes.
- **Sweets per win** (P5, `lib/app/rewards.dart`): the first win pays
  10 + 5 × stars. A replay pays +5 per star above the scoop's best, else 0.
  The ×2 ad doubles only what the win paid.
- **Tutorial lessons:**
  - Level 1: tap.
  - Level 2: drag and undo.
  - Level 4: groups.
  - Level 11: pouches and Peek.
  - Level 21: locked tube.
  - Level 41: double lock. Level 61: tall tubes. Level 101: Big Kitchen.
    These twist lessons show the first time a player meets the twist, even
    on an old save.
- **Rush levels** are every 10th level from 40 to 100.

## Progression (built 2026-11-06)

The owner chose the designer's recommended bundle: P5, P1a, P6a, P8, P10
and P7, built in that order (one commit each). Rules:

- **Bean Jars** (P1a, `lib/app/chapters.dart`): 20 jars of 10 scoops.
  The 10th scoop is the Lid scoop (+10 on its first win). Winning it seals
  the jar: +50 sweets, +150 more on every 5th (gold) jar, and one free
  Extra tube in `boosterStock`, used before any ad or price.
- **Twists** (P6a): double lock from 41, tall 5-bean tubes from 61, the Big
  Kitchen at 101 (101–103 are lock-free breathers), both twists together
  from 141. See the level data caveat below.
- **Rank** (P8, `lib/app/rank.dart`): XP = 10 per first clear + 5 per
  star + 30 per sealed jar + 10 per gold spoon, worked out from the save.
  Rank n needs 15n(n+1)/2 XP; 25 ranks; +25 sweets per rank gained. P2 is
  not built (P8 replaces it).
- **Master spoons** (P10, `Spoons` in `lib/app/rewards.dart`): ★★★ on a
  replay with no Undo (the free one counts), Peek or Extra tube. +10 sweets;
  all 10 in a jar pay +50 and gold-rim the jar on the shelf.
- **Candy Road** (P7, `lib/ui/road_screen.dart`): the Levels screen.
  Signposts sit 10 stops before each twist (`RoadLayout.signs`).
- **Home and Pantry** (UI review, option J2): a new save sees only the logo,
  star and sweets counts, Play, Levels, Settings and Remove ads. From the first win a jar chip shows the current
  jar; tapping it (or the rank badge, from rank 2) opens the Pantry sheet
  with rank, jar goal and the shelf. Result card shows each extra reward as
  a chip plus a total.

New save keys (defaults keep old saves working): `jarsSealed` (old saves:
every jar whose Lid scoop is won, no back-pay), `boosterStock`,
`rankPaid` (old saves: their current rank, no back-pay), `spoons`
(starts empty), `roadSeen`, `jarChipSeen` (one-time chip explainer).

`test/result_layout_test.dart` renders the busiest result card at 360×640
with real Roboto and fails on overflow. Run it after changing that card.

## ⚠️ Level data caveat

`assets/levels/levels.json` was hand-tuned after generation (commit 76f65db):

- 43 spike levels lost their locked tube. Level 21 keeps its lock for the
  tutorial.
- The 7 rush levels from 40 to 100 each got an extra empty tube.
- Par was recomputed.

These levels were found with simulated play. Level 46, for example, went from a
0.7% win rate to 75%.

**`tool/generate_levels.dart` does not know about these edits.** Running it
would bring the spikes back. Before you regenerate, port the rules into
`lib/levels/generator.dart`:

- no lock except on level 21;
- rush levels get 2 spare tubes;
- then re-run the difficulty simulation.

(The commit message says "57 levels / 50 unlocked". The real numbers are 50
levels changed and 43 locks removed.)

The P6a twists were then applied on top with `dart run tool/twists.dart`,
which edits `levels.json` in place and is safe to rerun. It keeps a change
only if `tool/sim.dart` (a simulated player calibrated against
`docs/game-design/sim.csv`) wins the new board about as often as the old
one. Regenerating with `tool/generate_levels.dart` would lose both the
hand-tuning and the twists; if you ever do, run `tool/twists.dart` after it.

## Open decisions

Decided 2026-11-06: build the recommended bundle, using the designer's
recommended answer wherever a question was open. That means P5 (not P5b);
free Extra tubes as jar rewards; no catch-up gift for existing players
(past jars sealed silently, rank starts where it is); jars of 10; Lid
scoops on 101–200 keep the normal layout; re-tuning 41–200 is fine (stars
stay); P8 instead of P2; the free undo breaks the spoon.

Still open: a sweets sink (P9 or P3, next per the designer), one calendar
habit (P4 or P11) with P13a, whether P6b and P13b are in scope, the undo
price balance and the final app name. The original questions follow.

The game-designer's proposal is at
https://claude.ai/artifact/HK3jTbyrASDKteY8D43Ndo. The feedback behind it was
that players don't feel progress and have no larger goal.

It found five problems:

- After level 21 there is nothing new for 179 levels.
- The home screen shows no goal.
- Stars buy nothing.
- Sweets have nothing to spend on.
- Replays can be farmed for sweets.

Its proposals:

- **P1 Bean Jars.** Group levels into 10-level chapters on a Pantry shelf.
  Sealing a jar pays 50 sweets and gives an extra-tube booster. Variants P1a
  and P1b.
- **P2 Star treat box:** a reward every 30 stars.
- **P3 Cosmetics shop:** caps 150, backdrops 400, lids 800.
- **P4 Daily treat and streak.**
- **P5 Replay pay:** replays pay only the star difference. The alternative,
  P5b, pays a flat +5.

It recommends building P1a + P5 first.

Questions still to answer:

1. Which proposals should be built?
2. P5 or P5b?
3. Are free boosters OK as rewards?
4. Existing players: seal their finished jars silently, or give a catch-up gift?
5. Jar size: 10 levels or 20?

### Round 2: P6–P13

These were added to the same page. A copy of the page is in
`docs/game-design/proposal.html` (it opens offline), with the data behind it:
`sim.csv`, `lock2.csv` and `cap5.csv`.

What the level data shows:

- After level 30, every board uses the same parts.
- At level 101 the simulated win rate drops from 78% to 35%, and by levels
  181–200 it is 18–26%.

The options:

- **P6 A new twist every 20 levels.**
  - Level 41: a lock that needs 2 sealed tubes. On levels 101–200, 52 of 100
    boards stay solvable with it.
  - Level 61: tall 5-bean tubes.
  - Level 101: a named "Big Kitchen" stage, with a lesson.
  - P6a uses only today's rules. P6b adds a label tube and sticky beans.
- **P7 Candy Road:** a map-style level list. It replaces P1b.
- **P8 Player rank:** XP and 25 ranks, +25 sweets per rank. Use it instead of P2.
- **P9 Bean Album:** 48 stickers in packs of 3, earned or bought for 120 sweets.
  It is a sweets sink.
- **P10 Master spoons:** a gold spoon for 3 stars on a replay with no boosters.
  This needs an `undoUsed` flag.
- **P11 Weekly Bake-off:** 5 fixed boards a week. It needs a separate level
  source and overlaps P4.
- **P12 Customer orders:** order slips that are filled by sealing flavours.
- **P13 Comeback hooks.** P13a is a welcome-back gift. P13b is opt-in reminders,
  which add a new package and the Android 13 notification permission.

The recommended bundle is P1a + P5 + P6a + P8 + P10, then P7. Build order:

1. P5
2. P1a
3. P6a
4. P8
5. P10
6. P7

After that, add a sweets sink (P9 or P3). Then add P4 or P11, together with
P13a.

Round 2 questions:

1. Which of P6–P13 should be built, and is the bundle right?
2. Is it OK to re-tune levels 41–200 that players have already starred? Their
   stars stay.
3. Should P8 replace P2? Should existing players get a catch-up gift for ranks
   they already have?
4. Sticker packs: random, or fixed rewards?
5. Should the free undo cost the spoon? The designer recommends yes.
6. P11 or P4 as the calendar habit?
7. Are push notifications (P13b) in scope?

Older open items:

- Undo for sweets costs 1 while the ad option gives 3. Is that balance right?
- The final app name. "Jelly Beans" is a working title.

To build a chosen set, run the `game-designer` agent in the **build** phase
with the chosen options.

## Previews

- Web build of the current game: https://claude.ai/artifact/D1EV5qf1k1CSus6m7xCDDN
- Game-design proposal (P1–P13): https://claude.ai/artifact/HK3jTbyrASDKteY8D43Ndo, with a copy in `docs/game-design/`
- Store assets (screenshots, feature graphic, listing): `store/`

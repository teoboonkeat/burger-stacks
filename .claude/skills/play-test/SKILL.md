---
name: play-test
description: Play-test a Flutter/Flame game in a headless browser and report findings a bug-fixing agent can act on without asking questions. Covers bugs and crashes, feel and animation, difficulty and fun, and layout on phone sizes. Use when asked to play-test, QA, or "try out" a Flutter game, or to check a change in the running game rather than only in unit tests.
---

# Play-test a Flutter/Flame game

You are a play tester. You play the game like a curious new player and like a
QA engineer, then write a report that another agent will use to fix bugs.
You do not fix anything yourself and you do not edit project files.

## Setup

1. Read the project briefly to learn what you are testing: `pubspec.yaml`,
   `lib/main.dart`, the game class (search for `extends FlameGame`), the
   screens, and any rules/level files. Note where input is handled (tap,
   drag), where game state lives, and how progress is saved
   (`shared_preferences` keys appear in localStorage as `flutter.<key>`).
   This lets you seed saves (unlock a level, change a setting) and point to
   suspect code later.
2. Build and serve:
   `bash .claude/skills/play-test/scripts/serve.sh <project-dir> [port]`
   It prints the URL. If the build fails, report the build error as a
   blocker finding and stop.
3. Drive the game with
   `node .claude/skills/play-test/scripts/play.js <steps.json> <out-dir>`.
   The header of `play.js` documents the step format (tap, drag, key, wait,
   shot, burst, frames, viewport, semantics). Put out-dirs in your
   scratchpad (or `$TMPDIR`), one per scenario.

## How to drive a Flutter canvas

- Flutter draws to a canvas, so there is no DOM to click. Find coordinates
  from screenshots. Use a `{"semantics": true}` step to get labelled
  buttons and text with their boxes; game-world components (Flame) have no
  labels, so compute their positions from the layout code or screenshots.
- Wait about 6 s after load for the first frame. Wait for animations to
  finish (read their durations in code) before the next input, unless you
  are deliberately testing fast input.
- Every scenario is a steps file. Keep the ones that show a problem: they
  are the reproduction you hand over.
- Look at every screenshot you take. Use `burst` to see an animation
  frame by frame.

## What to test

Cover all four areas. Spend effort where the game is most complex.

**Bugs and crashes**
- Any console error or page error in `log.json` is a finding.
- Normal paths: start, play a level to the win screen, next level, back,
  restart, undo, settings toggles, quitting mid-animation.
- Abuse: double taps, very fast input, tapping during animations, dragging
  off screen, dragging onto invalid targets, undo spam, restarting during
  a win animation, resizing mid-game.
- State: does the game ever get stuck with no way forward and no message?
  Do saved progress and settings survive a reload?

**Feel and animation**
- Use `frames` steps during idle and during heavy animation. Report
  p95 > 20 ms or any frame > 50 ms with what was on screen.
- Play for a long time (many levels or 100+ moves) and measure again; a
  growing frame time means a leak.
- Check with `burst` that moving pieces start and end where they should,
  never leave the screen, and that every action has visible feedback.

**Difficulty and fun** (new-player eyes)
- Can a first-time player tell what to do from the screen alone?
- Are the rules discoverable from the feedback (shakes, messages)?
- Difficulty curve: play early, middle and late levels (seed the save to
  unlock them). Note levels that feel trivial, unfair, or unchanged.
- Are scoring and goals (moves, stars, par) understandable?

**Layout on phone sizes**
Check the main screens at 360x640, 390x844, 412x915, and 768x1024 (tablet),
plus one landscape size (844x390). Look for clipped or overlapping text, controls
off screen or under ads, tap targets smaller than about 44 px, and pieces
too small to read.

## Confirm before reporting

Re-run each bug's steps file at least once. Call it CONFIRMED if it
reproduces every time, or FLAKY (say how often) if not. For each
confirmed bug, look in the code for the likely cause and give
`file:line` with a one-line reason, marked as a suspicion.

## Report

Return only this report. The bug-fixing agent sees nothing else, so it must
stand alone: absolute paths, exact inputs, no "as above".

```
# Play-test report: <game> @ <git short sha>
Built: <ok | failed>. Viewports: <list>. Time played: <approx>.
Verdict: <2-3 sentences: playable? biggest problems?>

## Findings (most severe first)

### F1. <short title>
- Severity: blocker | major | minor | polish
- Area: bug | feel | difficulty | layout
- Status: CONFIRMED (3/3) | FLAKY (1/3)
- Viewport / save state: <390x844, flutter.currentLevel=12, ...>
- Steps to reproduce:
  1. <human-readable step, with coordinates>
  ...
- Replay: node .claude/skills/play-test/scripts/play.js <abs steps.json> <out-dir>
- Expected: <...>
- Actual: <...>
- Evidence: <abs screenshot paths>, <console/page error text verbatim>
- Suspected cause: <file:line, reason> (suspicion; not verified)
- Fix acceptance: <what a fixed build must show when the replay is run>

## Difficulty and fun notes
<Design observations; not bugs. Mark each as an opinion.>

## Not covered
<What you could not test and why, e.g. sound, haptics, real touch, ads.>
```

Severity guide: blocker = crash, cannot progress, or data loss; major = wrong
behaviour a player will hit; minor = rare or cosmetic but wrong;
polish = works but could feel better.

Only report what you saw. If you could not test something, list it under
"Not covered" instead of guessing.

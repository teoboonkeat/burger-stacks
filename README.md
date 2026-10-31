# Burger Stacks

Casual burger sort puzzle built with Flutter + Flame (see the handoff spec).

- `lib/logic/` – pure-Dart rules, undo, solver
- `lib/levels/` – level model and generator; `dart run tool/generate_levels.dart` rewrites `assets/levels/levels.json`
- `lib/game/` – Flame board (code-drawn ingredients, animations)
- `lib/ui/` – Home, Levels, Gameplay HUD, Stuck sheet, Order up, Settings
- `lib/ads/` – interstitial caps (`AdPolicy`) and a simulated `AdService`

Ads, purchases and Firebase are simulated with dialogs for now (milestones 6–7).
Every push builds a release APK via GitHub Actions and attaches it to a prerelease.

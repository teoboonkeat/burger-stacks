# Jelly Beans (working title)

Casual jelly bean sort puzzle built with Flutter + Flame.

- `lib/logic/` – pure-Dart rules, undo, solver
- `lib/levels/` – level model and generator; `dart run tool/generate_levels.dart` rewrites `assets/levels/levels.json`
- `lib/game/` – Flame board: dispenser tubes and beans drawn in code (`bean_painter.dart`)
- `lib/ui/` – Home, Levels, Gameplay HUD, Stuck sheet, Sweet! jar screen, Settings
- `lib/ads/` – interstitial caps (`AdPolicy`) and a simulated `AdService`
- `assets/audio/` – synthesised tick / clink / rattle + chime

Flavours (level keys, in enum order): berry, peach, lime, grape, lemon, cola.

Ads, purchases and Firebase are simulated with dialogs for now.
Every push builds a release APK via GitHub Actions and attaches it to a prerelease.

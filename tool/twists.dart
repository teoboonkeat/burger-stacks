// Run: dart run tool/twists.dart
//
// P6a, a new kitchen twist every 20 scoops: applies the twist schedule to
// assets/levels/levels.json in place, keeping the hand-tuning described in
// HANDOFF.md. Safe to run again: a board that already has its twist is
// left alone.
//
//   41  Double lock: a spare tube that opens after 2 sealed tubes.
//   61  Tall tubes: 5 beans per tube.
//  101  Big Kitchen: a named stage; 101 to 103 lose their lock (breathers).
//  141  Double lock and tall tubes on the same board.
//
// Each twist opens with 2 easier boards, then mixes into later boards. A
// change is kept only if the simulated player (tool/sim.dart) wins the
// new board about as often as the old one, so the difficulty curve stays
// where the play-tested hand-tuning put it. Par is always the solver's.
import 'dart:convert';
import 'dart:io';

import 'package:jelly_beans/levels/generator.dart';
import 'package:jelly_beans/levels/level.dart';
import 'package:jelly_beans/logic/solver.dart';

import 'sim.dart';

const _path = 'assets/levels/levels.json';
const _sim = SimPlayer();

/// Most a twist may lower the simulated win rate of the board it changes.
const _maxDrop = .05;

/// Win rates a new board may have when it replaces one the simulated
/// player wins [old] of the time: about as hard, never a spike either way.
/// Very hard boards (a 6% board, say) may come up to 40%.
bool _close(double rate, double old) =>
    rate >= old - _maxDrop && rate <= (old + .15 < .4 ? .4 : old + .15);

double _rate(Level l) => _sim.winRate(l, runs: 160);

bool _isTall(Level l) => l.capacity > 4;
int _lockNeed(Level l) =>
    l.tubes.map((t) => t.unlockAt ?? 0).fold(0, (a, b) => a > b ? a : b);

/// [l] with its tubes replaced and par re-solved; null if unsolvable.
Level? _with(Level l, List<TubeSpec> tubes, {String? hint}) {
  final draft = Level(
      id: l.id, capacity: l.capacity, par: 0, seed: l.seed, tubes: tubes);
  final par = Solver().solve(draft.toBoard());
  if (par == null || par > 60) return null;
  return Level(
      id: l.id,
      capacity: l.capacity,
      par: par,
      seed: l.seed,
      hint: hint ?? l.hint,
      tubes: tubes);
}

/// The first spare tube locked behind [need] sealed tubes, other spares
/// open.
Level? _lockSpare(Level l, int need, {String? hint}) {
  var done = false;
  final tubes = [
    for (final t in l.tubes)
      if (t.stack.isEmpty && !done && (done = true))
        TubeSpec(const [], unlockAt: need)
      else if (t.stack.isEmpty)
        const TubeSpec([])
      else
        t
  ];
  return _with(l, tubes, hint: hint);
}

Level? _unlock(Level l) => _with(l, [
      for (final t in l.tubes) t.stack.isEmpty ? const TubeSpec([]) : t
    ]);

/// A new 5-bean board for [l]'s scoop that [ok] accepts, or null.
Level? _tall(Level l, Tier tier, bool Function(Level, double) ok,
        {String? hint}) =>
    _fresh(l, tier, ok, capacity: 5, hint: hint);

/// A newly generated board for [l]'s scoop that [ok] accepts, or null.
Level? _fresh(Level l, Tier tier, bool Function(Level, double) ok,
    {required int capacity, String? hint}) {
  for (var k = 0; k < 400; k++) {
    final g = generateLevel(l.id, l.id * 1000 + 500 + k,
        capacity: capacity, tier: tier);
    if (g == null || g.par > 26) continue;
    final rate = _rate(g);
    if (ok(g, rate)) {
      return Level(
          id: l.id,
          capacity: capacity,
          par: g.par,
          seed: g.seed,
          hint: hint ?? l.hint,
          tubes: g.tubes);
    }
  }
  return null;
}

void main() {
  final levels = parseLevels(jsonDecode(File(_path).readAsStringSync()) as List);
  final before = {for (final l in levels) l.id: _rate(l)};
  final log = <String>[];

  void apply(int id, String what, Level? Function(Level old) make,
      {bool Function(Level, double)? accept}) {
    final old = levels[id - 1];
    final nu = make(old);
    if (nu == null) {
      log.add('$id $what: no board found, kept');
      return;
    }
    final rate = _rate(nu);
    final keep = accept?.call(nu, rate) ?? rate >= before[id]! - _maxDrop;
    log.add('$id $what: par ${old.par}->${nu.par}, '
        'sim ${(before[id]! * 100).round()}%->${(rate * 100).round()}% '
        '${keep ? 'kept' : 'rejected'}');
    if (keep) levels[id - 1] = nu;
  }

  // 41: double lock. Two easier boards first, then every 1-lock from 43
  // up becomes a double lock wherever that keeps the board as winnable.
  // Today's board where a double lock still leaves it winnable, otherwise
  // a new board with 4 flavours and 1 or 2 pouches.
  for (final id in [41, 42]) {
    if (_lockNeed(levels[id - 1]) >= 2) continue;
    final hint =
        id == 41 ? 'A double lock opens once you seal two tubes.' : null;
    apply(
        id,
        'double lock (intro)',
        (l) =>
            _lockSpare(_unlock(l)!, 2, hint: hint) ??
            _fresh(l, const Tier(4, 2, 1, 2, 1, lockNeed: 2),
                (g, rate) => rate >= .7,
                capacity: 4, hint: hint),
        accept: (_, rate) => rate >= .6);
  }

  // 61: tall tubes. Two easier boards (4 flavours), then a few per stretch.
  for (final id in [61, 62]) {
    if (_isTall(levels[id - 1])) continue;
    apply(
        id,
        'tall tubes (intro)',
        (l) => _tall(l, const Tier(4, 2, 1, 2, 0), (g, rate) => rate >= .75,
            hint: id == 61 ? 'Tall tubes hold five beans.' : null),
        accept: (_, rate) => rate >= .75);
  }
  for (final id in [66, 74, 78, 85, 93, 97]) {
    if (_isTall(levels[id - 1])) continue;
    final old = before[id]!;
    apply(id, 'tall tubes',
        (l) => _tall(l, const Tier(5, 2, 2, 4, 0), (g, rate) => _close(rate, old)),
        accept: (_, rate) => _close(rate, old));
  }

  // 101: Big Kitchen. The first three boards are breathers with no lock.
  for (final id in [101, 102, 103]) {
    if (_lockNeed(levels[id - 1]) == 0) continue;
    apply(id, 'Big Kitchen breather', _unlock, accept: (_, _) => true);
  }

  // 141: double lock and tall tubes together; two easier boards first.
  for (final id in [141, 142]) {
    if (_isTall(levels[id - 1])) continue;
    apply(
        id,
        'tall + double lock (intro)',
        (l) => _tall(l, const Tier(5, 2, 2, 3, 1, lockNeed: 2),
            (g, rate) => rate >= .5,
            hint: id == 141 ? 'Tall tubes and a double lock, together.' : null),
        accept: (_, rate) => rate >= .5);
  }
  for (final id in [107, 115, 124, 133, 152, 166, 173, 184, 192]) {
    if (_isTall(levels[id - 1])) continue;
    final old = before[id]!;
    apply(id, 'tall tubes',
        (l) => _tall(l, const Tier(6, 2, 4, 6, 0), (g, rate) => _close(rate, old)),
        accept: (_, rate) => _close(rate, old));
  }
  for (final id in [157, 178, 196]) {
    if (_isTall(levels[id - 1])) continue;
    final old = before[id]!;
    apply(
        id,
        'tall + double lock',
        (l) => _tall(l, const Tier(6, 2, 3, 5, 1, lockNeed: 2),
            (g, rate) => _close(rate, old)),
        accept: (_, rate) => _close(rate, old));
  }

  // Double locks mixed in: upgrade 1-locks from 43 on, except breathers.
  for (final l in [...levels]) {
    if (l.id < 43 || l.id <= 103 && l.id >= 101) continue;
    if (_lockNeed(l) != 1) continue;
    apply(l.id, 'double lock', (l) => _lockSpare(l, 2));
  }

  final json = [for (final l in levels) l.toJson()];
  File(_path).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(json));
  log.forEach(stdout.writeln);

  // Band summary, before and after.
  for (final (a, b) in [(41, 60), (61, 100), (101, 140), (141, 200)]) {
    double avg(Map<int, double> m) =>
        [for (var i = a; i <= b; i++) m[i]!].reduce((x, y) => x + y) / (b - a + 1);
    final after = {for (final l in levels) l.id: _rate(l)};
    stdout.writeln('sim $a-$b: ${(avg(before) * 100).round()}% -> '
        '${(avg(after) * 100).round()}%');
  }
}

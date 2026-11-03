import 'package:flame_audio/flame_audio.dart';

import '../game/jelly_game.dart';

/// Short synthesised effects in assets/audio/.
///
/// Each sound plays from a small fixed pool of reusable players. (Playing
/// with FlameAudio.play creates a new native player per call that is never
/// released, which made the game slower the longer it was played.)
class Sfx {
  static const tick = 'tick.wav', clink = 'clink.wav', complete = 'rattle_chime.wav';
  static final Map<String, AudioPool> _pools = {};

  static Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([tick, clink, complete]);
      for (final (f, n) in [(tick, 2), (clink, 4), (complete, 2)]) {
        _pools[f] = await FlameAudio.createPool(f, maxPlayers: n);
      }
    } catch (_) {
      // Audio is optional; the game stays playable without it.
    }
  }

  static void forEvent(GameEvent e) {
    final file = switch (e) {
      GameEvent.pick => tick,
      GameEvent.land => clink,
      GameEvent.tubeComplete => complete,
      _ => null,
    };
    final pool = file == null ? null : _pools[file];
    if (pool == null) return;
    pool.start(volume: .7).then((_) {}, onError: (_) {});
  }
}

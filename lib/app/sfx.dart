import 'package:flame_audio/flame_audio.dart';

import '../game/jelly_game.dart';

/// Short synthesised effects in assets/audio/.
class Sfx {
  static const tick = 'tick.wav', clink = 'clink.wav', complete = 'rattle_chime.wav';

  static Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([tick, clink, complete]);
    } catch (_) {
      // Audio is optional; the game stays playable without it.
    }
  }

  static void forEvent(GameEvent e) {
    final file = switch (e) {
      GameEvent.pick => tick,
      GameEvent.drop => clink,
      GameEvent.tubeComplete => complete,
      _ => null,
    };
    if (file != null) FlameAudio.play(file, volume: .7).ignore();
  }
}

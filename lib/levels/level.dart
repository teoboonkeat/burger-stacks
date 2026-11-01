import '../logic/board.dart';

class TubeSpec {
  final List<String> stack;
  final int? unlockAt;
  const TubeSpec(this.stack, {this.unlockAt});

  factory TubeSpec.fromJson(Map<String, dynamic> j) => TubeSpec(
        (j['stack'] as List).cast<String>(),
        unlockAt: (j['locked'] as Map?)?['completeCount'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'stack': stack,
        if (unlockAt != null) 'locked': {'completeCount': unlockAt},
      };
}

class Level {
  final int id;
  final int capacity;
  final int par;
  final int seed;
  final String? hint;
  final List<TubeSpec> tubes;
  const Level({
    required this.id,
    required this.capacity,
    required this.par,
    required this.tubes,
    this.seed = 0,
    this.hint,
  });

  factory Level.fromJson(Map<String, dynamic> j) => Level(
        id: j['id'] as int,
        capacity: j['capacity'] as int? ?? 4,
        par: j['par'] as int,
        seed: j['seed'] as int? ?? 0,
        hint: j['hint'] as String?,
        tubes: (j['tubes'] as List)
            .map((p) => TubeSpec.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'capacity': capacity,
        'par': par,
        'seed': seed,
        if (hint != null) 'hint': hint,
        'tubes': tubes.map((p) => p.toJson()).toList(),
      };

  Board toBoard() => Board(
        tubes.map((p) {
          return Tube(
            p.stack.map((k) {
              final hidden = k.startsWith('?');
              return Piece(ingredientFromKey(hidden ? k.substring(1) : k),
                  hidden: hidden);
            }).toList(),
            unlockAt: p.unlockAt,
          );
        }).toList(),
        capacity: capacity,
      );
}

List<Level> parseLevels(List<dynamic> json) =>
    json.map((e) => Level.fromJson(e as Map<String, dynamic>)).toList();

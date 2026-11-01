// One-shot migration of assets/levels/levels.json to Jelly Beans names.
// Run: dart run tool/migrate_levels_to_jelly.dart
// Renames ingredient keys (same enum order) and the "plates" key; layouts,
// par, seeds and lock rules are untouched.
import 'dart:convert';
import 'dart:io';

const flavours = {
  'patty': 'berry',
  'cheese': 'peach',
  'tomato': 'lime',
  'lettuce': 'grape',
  'onion': 'lemon',
  'pickle': 'cola',
};

const hints = {
  1: 'Tap a tube to lift its top bean, then tap another tube to drop it.',
  4: 'Matching beans on top lift together as one group.',
  11: 'Paper pouches hide a bean until it reaches the top.',
  21: 'A locked tube opens once you fill one tube.',
};

String mapPiece(String k) {
  final hidden = k.startsWith('?');
  final name = hidden ? k.substring(1) : k;
  final out = flavours[name] ?? (throw FormatException('Unknown key $name'));
  return '${hidden ? '?' : ''}$out';
}

void main() {
  final f = File('assets/levels/levels.json');
  final levels = jsonDecode(f.readAsStringSync()) as List;
  final out = [
    for (final l in levels.cast<Map<String, dynamic>>())
      {
        for (final e in l.entries)
          if (e.key == 'plates')
            'tubes': [
              for (final p in (e.value as List).cast<Map<String, dynamic>>())
                {
                  for (final pe in p.entries)
                    pe.key: pe.key == 'stack'
                        ? (pe.value as List).cast<String>().map(mapPiece).toList()
                        : pe.value
                }
            ]
          else if (e.key == 'hint')
            'hint': hints[l['id']] ?? e.value
          else
            e.key: e.value
      }
  ];
  f.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  stdout.writeln('Migrated ${out.length} levels');
}

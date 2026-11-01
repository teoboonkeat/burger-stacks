// Run: dart run tool/generate_levels.dart
import 'dart:convert';
import 'dart:io';

import 'package:jelly_beans/levels/generator.dart';

void main(List<String> args) {
  final count = args.isEmpty ? 200 : int.parse(args.first);
  final levels = generateAll(count);
  // Levels 101+ are sorted by solver move count (ids reassigned).
  final tail = levels.sublist(100.clamp(0, levels.length))
    ..sort((a, b) => a.par.compareTo(b.par));
  final ordered = [...levels.take(100), ...tail];
  final json = [
    for (var i = 0; i < ordered.length; i++)
      {...ordered[i].toJson(), 'id': i + 1}
  ];
  File('assets/levels/levels.json')
      .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(json));
  stdout.writeln('Wrote ${json.length} levels');
}

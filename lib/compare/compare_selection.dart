import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

List<String>? normalizeFolderComparison(Iterable<String> images) {
  final normalized = LinkedHashSet<String>.from(
    images
        .where((path) => path.isNotEmpty)
        .map((path) => File(path).absolute.path),
  ).toList(growable: false);
  if (normalized.length < 2 || normalized.length > 4) return null;

  final folder = p.dirname(normalized.first);
  if (normalized.any((path) => p.dirname(path) != folder)) return null;
  return normalized;
}

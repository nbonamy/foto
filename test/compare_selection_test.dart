import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foto/compare/compare_selection.dart';

void main() {
  test('accepts two to four unique photos in one exact folder', () {
    final root = Directory.systemTemp.path;

    final result = normalizeFolderComparison([
      '$root/foto-folder/a.jpg',
      '$root/foto-folder/b.jpg',
      '$root/foto-folder/a.jpg',
    ]);

    expect(result, hasLength(2));
    expect(
        result!.every((path) => path.startsWith('$root/foto-folder/')), true);
  });

  test('rejects photos from different folders', () {
    final root = Directory.systemTemp.path;

    expect(
      normalizeFolderComparison([
        '$root/foto-folder/a.jpg',
        '$root/another-folder/b.jpg',
      ]),
      isNull,
    );
  });

  test('rejects selections outside the two-to-four photo range', () {
    final root = Directory.systemTemp.path;

    expect(normalizeFolderComparison(['$root/foto-folder/a.jpg']), isNull);
    expect(
      normalizeFolderComparison(
        List.generate(5, (index) => '$root/foto-folder/$index.jpg'),
      ),
      isNull,
    );
  });
}

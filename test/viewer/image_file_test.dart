import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foto/viewer/image.dart';

void main() {
  group('ImageFile', () {
    late Directory tempDirectory;
    late File file;

    setUp(() {
      tempDirectory = Directory.systemTemp.createTempSync('foto_image_file_');
      file = File('${tempDirectory.path}/image.jpg')
        ..writeAsBytesSync(<int>[1]);
    });

    tearDown(() {
      tempDirectory.deleteSync(recursive: true);
    });

    test('uses a stable key until a path is explicitly invalidated', () {
      final ImageFile first = ImageFile(file.path);
      final ImageFile second = ImageFile(file.path);

      expect(second, first);
      expect(second.hashCode, first.hashCode);

      ImageFile.invalidatePath(file.path);
      final ImageFile invalidated = ImageFile(file.path);

      expect(invalidated, isNot(first));
    });

    test('changes its key when a file is modified outside the app', () {
      final ImageFile before = ImageFile(file.path);
      file.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 1)));

      final ImageFile after = ImageFile(file.path);

      expect(after, isNot(before));
    });

    test('can represent a file that disappeared during navigation', () {
      file.deleteSync();

      expect(() => ImageFile(file.path), returnsNormally);
    });
  });
}

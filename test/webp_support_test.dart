import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:foto/utils/utils.dart';

// A 2 x 3 lossless WebP generated specifically for this test.
const _webp =
    'UklGRjIAAABXRUJQVlA4TCUAAAAvAYAAAC8gEEjaH3qN+RcQFPk/2vwHH0QCg0AgDVFkMMAR/Y8GAA==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late File image;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('foto-webp-');
    image = File('${directory.path}/image.webp');
    await image.writeAsBytes(base64Decode(_webp));
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('reads WebP dimensions for thumbnails, inspector, and viewer scaling',
      () {
    final size = Utils.imageSize(image.path);

    expect(size.width, 2);
    expect(size.height, 3);
  });

  test('Flutter image codec decodes WebP for gallery and viewer rendering',
      () async {
    final codec = await ui.instantiateImageCodec(await image.readAsBytes());
    addTearDown(codec.dispose);
    final frame = await codec.getNextFrame();
    addTearDown(frame.image.dispose);

    expect(frame.image.width, 2);
    expect(frame.image.height, 3);
  });
}

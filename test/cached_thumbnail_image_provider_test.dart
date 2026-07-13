import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/utils/cached_thumbnail_image_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late File original;
  late File cached;

  CachedThumbnailImageProvider provider({
    DateTime? modificationDate,
    int? fileSize = 42,
    int pixelSize = 960,
    ThumbnailPathResolver? resolver,
  }) {
    return CachedThumbnailImageProvider(
      path: original.path,
      modificationDate: modificationDate ?? DateTime(2026, 7, 13),
      fileSize: fileSize,
      pixelSize: pixelSize,
      resolver: resolver,
    );
  }

  Future<ImageInfo> load(ImageProvider imageProvider) {
    final completer = Completer<ImageInfo>();
    final stream = imageProvider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info);
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  setUp(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'foto-thumbnail-provider-',
    );
    final bytes = await File('assets/img/foto.png').readAsBytes();
    original = await File('${temporaryDirectory.path}/original.png')
        .writeAsBytes(bytes);
    cached =
        await File('${temporaryDirectory.path}/cached.png').writeAsBytes(bytes);
  });

  tearDown(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await temporaryDirectory.delete(recursive: true);
  });

  test('source metadata participates in decoded-cache identity', () {
    final originalProvider = provider();

    expect(provider(), originalProvider);
    expect(
      provider(modificationDate: DateTime(2026, 7, 14)),
      isNot(originalProvider),
    );
    expect(provider(fileSize: 43), isNot(originalProvider));
    expect(provider(pixelSize: 1200), isNot(originalProvider));
  });

  testWidgets('loads the native cached thumbnail path', (tester) async {
    var resolveCount = 0;
    final imageProvider = provider(
      resolver: ({
        required path,
        required modificationDate,
        required fileSize,
        required pixelSize,
      }) async {
        resolveCount += 1;
        expect(path, original.path);
        expect(fileSize, 42);
        expect(pixelSize, 960);
        return cached.path;
      },
    );

    final info = (await tester.runAsync(() => load(imageProvider)))!;

    expect(resolveCount, 1);
    expect(info.image.width, greaterThan(0));
    expect(info.image.height, greaterThan(0));
  });

  testWidgets('falls back to the source when cache resolution fails',
      (tester) async {
    final imageProvider = provider(
      resolver: ({
        required path,
        required modificationDate,
        required fileSize,
        required pixelSize,
      }) {
        throw StateError('cache unavailable');
      },
    );

    final info = (await tester.runAsync(() => load(imageProvider)))!;

    expect(info.image.width, greaterThan(0));
    expect(info.image.height, greaterThan(0));
  });

  testWidgets('falls back when a resolved cache file disappears',
      (tester) async {
    final imageProvider = provider(
      resolver: ({
        required path,
        required modificationDate,
        required fileSize,
        required pixelSize,
      }) async {
        return '${temporaryDirectory.path}/missing.png';
      },
    );

    final info = (await tester.runAsync(() => load(imageProvider)))!;

    expect(info.image.width, greaterThan(0));
    expect(info.image.height, greaterThan(0));
  });
}

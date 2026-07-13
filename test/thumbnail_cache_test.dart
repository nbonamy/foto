import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/utils/thumbnail_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('foto_platform_utils/messages');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('clear removes native and decoded thumbnail caches',
      (tester) async {
    var nativeClearCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'clearThumbnailCache');
      nativeClearCalls += 1;
      return true;
    });

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        FileImage(File('assets/img/foto.png')),
        context,
      ),
    );
    await tester.pump();
    expect(PaintingBinding.instance.imageCache.currentSize, greaterThan(0));

    await ThumbnailCache.clear();

    expect(nativeClearCalls, 1);
    expect(PaintingBinding.instance.imageCache.currentSize, 0);
    expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
  });
}

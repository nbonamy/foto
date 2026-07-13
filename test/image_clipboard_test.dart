import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/utils/image_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('foto_image_utils/messages');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('bitmap copy sends only the image path and awaits native completion',
      () async {
    final nativeResult = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      expect(call.method, 'copyImageToClipboard');
      expect(call.arguments, '/tmp/photo.webp');
      return nativeResult.future;
    });

    var completed = false;
    final copy = ImageUtils.copyImageToClipboard('/tmp/photo.webp').then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);
    nativeResult.complete(true);
    await copy;
    expect(completed, isTrue);
  });

  test('bitmap copy reports a false native result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);

    await expectLater(
      ImageUtils.copyImageToClipboard('/tmp/photo.jpg'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'clipboard_failed',
        ),
      ),
    );
  });
}

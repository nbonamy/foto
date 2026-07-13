import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/utils/platform_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('foto_platform_utils/messages');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('moveToTrash awaits the native operation', () async {
    final nativeResult = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      expect(call.method, 'moveToTrash');
      expect(call.arguments, '/tmp/photo.jpg');
      return nativeResult.future;
    });

    var completed = false;
    final move = PlatformUtils.moveToTrash('/tmp/photo.jpg').then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);
    nativeResult.complete(true);
    await move;
    expect(completed, isTrue);
  });

  test('moveToTrash rejects a false native result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);

    await expectLater(
      PlatformUtils.moveToTrash('/tmp/photo.jpg'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'trash_failed',
        ),
      ),
    );
  });

  test('moveToTrash propagates native errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'trash_failed', message: 'No permission');
    });

    await expectLater(
      PlatformUtils.moveToTrash('/tmp/photo.jpg'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.message,
          'message',
          'No permission',
        ),
      ),
    );
  });
}

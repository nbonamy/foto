import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
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

  test('instant fullscreen delegates entry and exit to the native window',
      () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return true;
    });

    await PlatformUtils.enterInstantFullScreen();
    await PlatformUtils.exitInstantFullScreen();

    expect(methods, ['enterInstantFullScreen', 'exitInstantFullScreen']);
  });

  test('appearance mode is forwarded to the native window', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });

    await PlatformUtils.setAppearance(ThemeMode.system);
    await PlatformUtils.setAppearance(ThemeMode.light);
    await PlatformUtils.setAppearance(ThemeMode.dark);

    expect(calls.map((call) => call.method), everyElement('setAppearance'));
    expect(
      calls.map((call) => call.arguments),
      orderedEquals(['system', 'light', 'dark']),
    );
  });

  test('map snapshots forward location appearance and pixel scale', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return Uint8List.fromList([1, 2, 3]);
    });

    final bytes = await PlatformUtils.renderMapSnapshot(
      latitude: 64.1466,
      longitude: -21.9426,
      dark: true,
      scale: 2,
      distanceMeters: 30000,
    );

    expect(received?.method, 'renderMapSnapshot');
    expect(received?.arguments, {
      'latitude': 64.1466,
      'longitude': -21.9426,
      'dark': true,
      'width': 560.0,
      'height': 300.0,
      'scale': 2.0,
      'distance': 30000.0,
    });
    expect(bytes, [1, 2, 3]);
  });

  test('thumbnail cache forwards stable source metadata', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return '/Users/test/Library/Caches/com.nabocorp.foto/thumb.jpg';
    });

    final cachedPath = await PlatformUtils.resolveCachedThumbnail(
      path: '/Volumes/Photos/image.jpg',
      modificationDate: DateTime.fromMicrosecondsSinceEpoch(1234567),
      fileSize: 987654,
    );

    expect(received?.method, 'resolveCachedThumbnail');
    expect(received?.arguments, {
      'path': '/Volumes/Photos/image.jpg',
      'modificationMicros': 1234567,
      'fileSize': 987654,
      'pixelSize': 960,
    });
    expect(cachedPath, endsWith('thumb.jpg'));
  });

  test('thumbnail cache clear requires native confirmation', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return true;
    });

    await PlatformUtils.clearThumbnailCache();

    expect(methods, ['clearThumbnailCache']);
  });

  test('visual similarity forwards both metadata identities', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'compareVisualSimilarity');
      expect(call.arguments, {
        'source': {
          'path': '/network/source.jpg',
          'modificationMicros': 1752422400123456,
          'fileSize': 120,
          'pixelSize': 960,
        },
        'candidate': {
          'path': '/network/candidate.jpg',
          'modificationMicros': 1752422400654321,
          'fileSize': -1,
          'pixelSize': 960,
        },
      });
      return 0.125;
    });

    final distance = await PlatformUtils.compareVisualSimilarity(
      sourcePath: '/network/source.jpg',
      sourceModificationDate:
          DateTime.fromMicrosecondsSinceEpoch(1752422400123456),
      sourceFileSize: 120,
      candidatePath: '/network/candidate.jpg',
      candidateModificationDate:
          DateTime.fromMicrosecondsSinceEpoch(1752422400654321),
      candidateFileSize: null,
    );

    expect(distance, 0.125);
  });

  test('visual similarity rejects invalid native distances', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    await expectLater(
      PlatformUtils.compareVisualSimilarity(
        sourcePath: '/network/source.jpg',
        sourceModificationDate: DateTime(2026),
        sourceFileSize: 120,
        candidatePath: '/network/candidate.jpg',
        candidateModificationDate: DateTime(2026),
        candidateFileSize: 120,
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'visual_similarity_failed',
        ),
      ),
    );
  });

  test('instant fullscreen reports native failures', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);

    await expectLater(
      PlatformUtils.enterInstantFullScreen(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'fullscreen_failed',
        ),
      ),
    );
  });
}

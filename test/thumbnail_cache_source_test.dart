import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native thumbnail cache stays bounded and off the main thread', () {
    final source = File('macos/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('maxConcurrentOperationCount = 2'));
    expect(source, contains('CGImageSourceCreateThumbnailAtIndex'));
    expect(source, contains('cacheLimitBytes = 1024 * 1024 * 1024'));
    expect(source, contains('cacheTargetBytes = 900 * 1024 * 1024'));
    expect(source, contains('addBarrierBlock'));
    expect(source, contains('.cachesDirectory'));
  });
}

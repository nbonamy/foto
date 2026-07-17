import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native visual features reuse the bounded thumbnail pipeline', () {
    final source = File('macos/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('import Vision'));
    expect(source, contains('VNGenerateImageFeaturePrintRequest()'));
    expect(
      source,
      contains('VNGenerateImageFeaturePrintRequestRevision1'),
    );
    expect(source, contains('requiringSecureCoding: true'));
    expect(source, contains('appendingPathExtension("vision")'));
    expect(source, contains('thumbnailCache.perform'));
    expect(source, contains('maxConcurrentOperationCount = 2'));
    expect(source, contains('compareVisualSimilarity'));
  });
}

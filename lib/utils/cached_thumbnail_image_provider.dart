import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'platform_utils.dart';

typedef ThumbnailPathResolver = Future<String> Function({
  required String path,
  required DateTime modificationDate,
  required int? fileSize,
  required int pixelSize,
});

/// Loads a locally cached thumbnail while preserving the original file as a
/// correctness fallback.
///
/// Source metadata is part of the provider identity, so Flutter's decoded
/// image cache invalidates at the same time as the native disk cache.
@immutable
class CachedThumbnailImageProvider
    extends ImageProvider<CachedThumbnailImageProvider> {
  const CachedThumbnailImageProvider({
    required this.path,
    required this.modificationDate,
    required this.fileSize,
    this.pixelSize = 960,
    this.resolver,
  });

  final String path;
  final DateTime modificationDate;
  final int? fileSize;
  final int pixelSize;

  @visibleForTesting
  final ThumbnailPathResolver? resolver;

  @override
  Future<CachedThumbnailImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<CachedThumbnailImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    CachedThumbnailImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1,
      debugLabel: path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Source path: $path'),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    CachedThumbnailImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);
    final resolvedPath = await _resolvePath();
    try {
      return await _decodePath(resolvedPath, key, decode);
    } catch (_) {
      if (resolvedPath == path) rethrow;
      return _decodePath(path, key, decode);
    }
  }

  Future<ui.Codec> _decodePath(
    String resolvedPath,
    CachedThumbnailImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final file = File(resolvedPath);
    if (await file.length() == 0) {
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('$file is empty and cannot be loaded as an image.');
    }
    return await decode(await ui.ImmutableBuffer.fromFilePath(resolvedPath));
  }

  Future<String> _resolvePath() async {
    try {
      return await (resolver ?? PlatformUtils.resolveCachedThumbnail)(
        path: path,
        modificationDate: modificationDate,
        fileSize: fileSize,
        pixelSize: pixelSize,
      );
    } catch (_) {
      // A cache failure must never make a source image disappear.
      return path;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is CachedThumbnailImageProvider &&
        other.path == path &&
        other.modificationDate == modificationDate &&
        other.fileSize == fileSize &&
        other.pixelSize == pixelSize;
  }

  @override
  int get hashCode => Object.hash(
        path,
        modificationDate,
        fileSize,
        pixelSize,
      );

  @override
  String toString() =>
      '${objectRuntimeType(this, 'CachedThumbnailImageProvider')}'
      '("$path", modified: $modificationDate, size: $fileSize, '
      'pixels: $pixelSize)';
}

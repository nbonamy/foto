import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlatformUtils {
  static final Map<String, Image> _iconCache = {};

  static const MethodChannel _mChannel =
      MethodChannel('foto_platform_utils/messages');

  static Future<void> moveToTrash(String filepath) async {
    final moved =
        await _mChannel.invokeMethod<bool>('moveToTrash', filepath) ?? false;
    if (!moved) {
      throw PlatformException(
        code: 'trash_failed',
        message: 'The item could not be moved to the Trash.',
        details: filepath,
      );
    }
  }

  static Future<String?> bundlePathForIdentifier(String identifier) {
    return _mChannel.invokeMethod('bundlePathForIdentifier', identifier);
  }

  static Future<void> openFilesWithBundleIdentifier(
      List<String> files, String bundleIdentifier) {
    return _mChannel.invokeMethod('openFilesWithBundleIdentifier', {
      'files': files,
      'identifier': bundleIdentifier,
    });
  }

  static Future<void> setAppearance(ThemeMode mode) async {
    final changed = await _mChannel.invokeMethod<bool>(
          'setAppearance',
          mode.name,
        ) ??
        false;
    if (!changed) {
      throw PlatformException(
        code: 'appearance_failed',
        message: 'The native window appearance could not be updated.',
        details: mode.name,
      );
    }
  }

  static Future<void> enterInstantFullScreen() async {
    await _invokeInstantFullScreen('enterInstantFullScreen');
  }

  static Future<void> exitInstantFullScreen() async {
    await _invokeInstantFullScreen('exitInstantFullScreen');
  }

  static Future<Uint8List?> renderMapSnapshot({
    required double latitude,
    required double longitude,
    required bool dark,
    double width = 560,
    double height = 300,
    double scale = 2,
    double distanceMeters = 60000,
  }) {
    return _mChannel.invokeMethod<Uint8List>('renderMapSnapshot', {
      'latitude': latitude,
      'longitude': longitude,
      'dark': dark,
      'width': width,
      'height': height,
      'scale': scale,
      'distance': distanceMeters,
    });
  }

  static Future<String> resolveCachedThumbnail({
    required String path,
    required DateTime modificationDate,
    required int? fileSize,
    int pixelSize = 960,
  }) async {
    final cachedPath = await _mChannel.invokeMethod<String>(
      'resolveCachedThumbnail',
      {
        'path': path,
        'modificationMicros': modificationDate.microsecondsSinceEpoch,
        'fileSize': fileSize ?? -1,
        'pixelSize': pixelSize,
      },
    );
    if (cachedPath == null || cachedPath.isEmpty) {
      throw PlatformException(
        code: 'thumbnail_cache_failed',
        message: 'The thumbnail cache returned no file.',
        details: path,
      );
    }
    return cachedPath;
  }

  static Future<void> clearThumbnailCache() async {
    final cleared =
        await _mChannel.invokeMethod<bool>('clearThumbnailCache') ?? false;
    if (!cleared) {
      throw PlatformException(
        code: 'thumbnail_cache_clear_failed',
        message: 'The thumbnail cache could not be cleared.',
      );
    }
  }

  static Future<double> compareVisualSimilarity({
    required String sourcePath,
    required DateTime sourceModificationDate,
    required int? sourceFileSize,
    required String candidatePath,
    required DateTime candidateModificationDate,
    required int? candidateFileSize,
    int pixelSize = 960,
  }) async {
    final distance = await _mChannel.invokeMethod<double>(
      'compareVisualSimilarity',
      {
        'source': _visualFeatureSource(
          path: sourcePath,
          modificationDate: sourceModificationDate,
          fileSize: sourceFileSize,
          pixelSize: pixelSize,
        ),
        'candidate': _visualFeatureSource(
          path: candidatePath,
          modificationDate: candidateModificationDate,
          fileSize: candidateFileSize,
          pixelSize: pixelSize,
        ),
      },
    );
    if (distance == null || !distance.isFinite || distance < 0) {
      throw PlatformException(
        code: 'visual_similarity_failed',
        message: 'The visual similarity service returned no valid distance.',
        details: {'source': sourcePath, 'candidate': candidatePath},
      );
    }
    return distance;
  }

  static Map<String, Object> _visualFeatureSource({
    required String path,
    required DateTime modificationDate,
    required int? fileSize,
    required int pixelSize,
  }) {
    return {
      'path': path,
      'modificationMicros': modificationDate.microsecondsSinceEpoch,
      'fileSize': fileSize ?? -1,
      'pixelSize': pixelSize,
    };
  }

  static Future<void> _invokeInstantFullScreen(String method) async {
    final changed = await _mChannel.invokeMethod<bool>(method) ?? false;
    if (!changed) {
      throw PlatformException(
        code: 'fullscreen_failed',
        message: 'The window could not change fullscreen mode.',
      );
    }
  }

  static Future<Image?> getPlatformIcon(String filepath) async {
    var data = await _mChannel.invokeMethod('getPlatformIcon', filepath);
    if (data == null) return null;
    if (data is String) {
      return _iconCache[data];
    } else {
      var key = data['key'];
      var png = data['png'];
      final Completer<Uint8List> bytesCompleter = Completer<Uint8List>();
      bytesCompleter.complete(png as Uint8List);
      var img = Image.memory(png);
      _iconCache[key] = img;
      return img;
    }
  }
}

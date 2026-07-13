import 'dart:async';
import 'package:flutter/services.dart';

enum ImageTransformation {
  rotate90CW,
  rotate90CCW,
  rotate180,
  flipHorizontal,
  flipVertical
}

class ImageUtils {
  static const MethodChannel _mChannel =
      MethodChannel('foto_image_utils/messages');

  static Future<DateTime> getCreationDate(String filepath) async {
    double epoch = await _mChannel.invokeMethod('getCreationDate', filepath);
    return DateTime.fromMicrosecondsSinceEpoch(
      (epoch * Duration.microsecondsPerSecond).round(),
    );
  }

  static Future<bool> transformImage(
      String filepath, ImageTransformation transformation,
      {double jpegCompression = 90}) async {
    var data = await _mChannel.invokeMethod('transformImage', {
      'filepath': filepath,
      'transformation': transformation.index,
      'jpegCompression': jpegCompression,
    });
    return data;
  }

  static Future<bool> losslessRotate(String filepath) async {
    var data = await _mChannel.invokeMethod('losslessRotate', filepath);
    return data;
  }

  static Future<void> copyImageToClipboard(String filepath) async {
    final copied =
        await _mChannel.invokeMethod<bool>('copyImageToClipboard', filepath) ??
            false;
    if (!copied) {
      throw PlatformException(
        code: 'clipboard_failed',
        message: 'The image could not be copied to the clipboard.',
        details: filepath,
      );
    }
  }
}

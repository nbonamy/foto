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
}

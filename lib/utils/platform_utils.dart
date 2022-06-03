import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlatformUtils {
  static final Map<String, Image> _iconCache = {};

  static const MethodChannel _mChannel =
      MethodChannel('foto_platform_utils/messages');

  static Future<void> moveToTrash(String filepath) async {
    _mChannel.invokeMethod('moveToTrash', filepath);
  }

  static Future<String?> bundlePathForIdentifier(String identifier) {
    return _mChannel.invokeMethod('bundlePathForIdentifier', identifier);
  }

  static Future<void> openFilesWithBundleIdentifier(List<String> files, String bundleIdentifier) {
    return _mChannel.invokeMethod('openFilesWithBundleIdentifier', {
      'files': files,
      'identifier': bundleIdentifier,
    });
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

// Copyright 2018 Evo Stamatov. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlatformUtils {
  static final Map<String, Image> _iconCache = {};

  static const MethodChannel _mChannel =
      MethodChannel('foto_platform_utils/messages');

  /// Returns a [Future], which completes to one of the following:
  ///
  ///   * the initially stored link (possibly null), on successful invocation;
  ///   * a [PlatformException], if the invocation failed in the platform plugin.
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

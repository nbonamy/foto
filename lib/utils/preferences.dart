import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

enum OverlayLevel {
  none,
  file,
  image,
  exif,
}

class Preferences {
  static OverlayLevel defaultOverlayLevel() {
    return OverlayLevel.image;
  }

  static Future<OverlayLevel> getOverlayLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getInt("overlayLevel") ?? Preferences.defaultOverlayLevel().index;
    return OverlayLevel.values[level];
  }

  static Future<void> saveOverlayLevel(OverlayLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("overlayLevel", level.index);
  }

  static Future<Rect> getWindowBounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var bounds = prefs.getString('bounds');
      var parts = bounds?.split(',');
      var left = double.parse(parts![0]);
      var top = double.parse(parts[1]);
      var right = double.parse(parts[2]);
      var bottom = double.parse(parts[3]);
      return Rect.fromLTRB(left, top, right, bottom);
    } catch (_) {
      return const Rect.fromLTWH(0, 0, 800, 600);
    }
  }

  static Future<void> saveWindowBounds(Rect rc) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('bounds',
        '${rc.left.toStringAsFixed(1)},${rc.top.toStringAsFixed(1)},${rc.right.toStringAsFixed(1)},${rc.bottom.toStringAsFixed(1)}');
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OverlayLevel {
  none,
  file,
  image,
  exif,
}

enum SortCriteria {
  alphabetical,
  chronological,
}

class Preferences extends ChangeNotifier {
  static OverlayLevel get defaultOverlayLevel {
    return OverlayLevel.image;
  }

  static SortCriteria get defaultSortCriteria {
    return SortCriteria.chronological;
  }

  static bool get defaultSortReversed {
    return false;
  }

  static bool get defaultShowFolders {
    return true;
  }

  static bool get defaultShowInspector {
    return false;
  }

  static int get defaultSlideshowDurationMs {
    return 3000;
  }

  static Preferences of(BuildContext context) {
    return Provider.of<Preferences>(context, listen: false);
  }

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  OverlayLevel get overlayLevel {
    return _enumPreference(
      'viewer.overlayLevel',
      OverlayLevel.values,
      Preferences.defaultOverlayLevel,
    );
  }

  set overlayLevel(OverlayLevel level) {
    if (overlayLevel == level) return;
    _prefs.setInt('viewer.overlayLevel', level.index);
    notifyListeners();
  }

  SortCriteria get sortCriteria {
    return _enumPreference(
      'browser.sort.criteria',
      SortCriteria.values,
      Preferences.defaultSortCriteria,
    );
  }

  set sortCriteria(SortCriteria type) {
    if (sortCriteria == type) return;
    _prefs.setInt('browser.sort.criteria', type.index);
    notifyListeners();
  }

  bool get sortReversed {
    return _prefs.getBool('browser.sort.reversed') ??
        Preferences.defaultSortReversed;
  }

  set sortReversed(bool reversed) {
    if (sortReversed == reversed) return;
    _prefs.setBool('browser.sort.reversed', reversed);
    notifyListeners();
  }

  bool get showFolders {
    return _prefs.getBool('browser.show_folders') ??
        Preferences.defaultShowFolders;
  }

  set showFolders(bool show) {
    if (showFolders == show) return;
    _prefs.setBool('browser.show_folders', show);
    notifyListeners();
  }

  bool get showInspector {
    return _prefs.getBool('browser.show_inspector') ??
        Preferences.defaultShowInspector;
  }

  set showInspector(bool show) {
    if (showInspector == show) return;
    _prefs.setBool('browser.show_inspector', show);
    notifyListeners();
  }

  int get slideshowDurationMs {
    final duration = _prefs.getInt('viewer.slideshow_duration');
    return duration != null && duration > 0
        ? duration
        : Preferences.defaultSlideshowDurationMs;
  }

  set slideshowDurationMs(int durationMs) {
    final validDuration =
        durationMs > 0 ? durationMs : Preferences.defaultSlideshowDurationMs;
    if (slideshowDurationMs == validDuration) return;
    _prefs.setInt('viewer.slideshow_duration', validDuration);
    notifyListeners();
  }

  Rect get windowBounds {
    try {
      var savedBounds = _prefs.getString('bounds');
      var parts = savedBounds?.split(',');
      var left = double.parse(parts![0]);
      var top = double.parse(parts[1]);
      var right = double.parse(parts[2]);
      var bottom = double.parse(parts[3]);
      final bounds = Rect.fromLTRB(left, top, right, bottom);
      if (!bounds.left.isFinite ||
          !bounds.top.isFinite ||
          !bounds.right.isFinite ||
          !bounds.bottom.isFinite ||
          bounds.width < 320 ||
          bounds.height < 240) {
        return const Rect.fromLTWH(0, 0, 800, 600);
      }
      return bounds;
    } catch (_) {
      return const Rect.fromLTWH(0, 0, 800, 600);
    }
  }

  set windowBounds(Rect rc) {
    _prefs.setString('bounds',
        '${rc.left.toStringAsFixed(1)},${rc.top.toStringAsFixed(1)},${rc.right.toStringAsFixed(1)},${rc.bottom.toStringAsFixed(1)}');
  }

  T _enumPreference<T>(String key, List<T> values, T fallback) {
    final index = _prefs.getInt(key);
    return index != null && index >= 0 && index < values.length
        ? values[index]
        : fallback;
  }
}

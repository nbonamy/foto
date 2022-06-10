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

  init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  // ignore: unnecessary_overrides
  void notifyListeners() {
    super.notifyListeners();
  }

  OverlayLevel get overlayLevel {
    final level = _prefs.getInt('viewer.overlayLevel') ??
        Preferences.defaultOverlayLevel.index;
    return OverlayLevel.values[level];
  }

  set overlayLevel(OverlayLevel level) {
    _prefs.setInt('viewer.overlayLevel', level.index);
  }

  SortCriteria get sortCriteria {
    final type = _prefs.getInt('browser.sort.criteria') ??
        Preferences.defaultSortCriteria.index;
    return SortCriteria.values[type];
  }

  set sortCriteria(SortCriteria type) {
    _prefs.setInt('browser.sort.criteria', type.index);
  }

  bool get sortReversed {
    return _prefs.getBool('browser.sort.reversed') ??
        Preferences.defaultSortReversed;
  }

  set sortReversed(bool reversed) {
    _prefs.setBool('browser.sort.reversed', reversed);
  }

  bool get showFolders {
    return _prefs.getBool('browser.show_folders') ??
        Preferences.defaultShowFolders;
  }

  set showFolders(bool show) {
    _prefs.setBool('browser.show_folders', show);
  }

  bool get showInspector {
    return _prefs.getBool('browser.show_inspector') ??
        Preferences.defaultShowInspector;
  }

  set showInspector(bool show) {
    _prefs.setBool('browser.show_inspector', show);
  }

  int get slideshowDurationMs {
    return _prefs.getInt('viewer.slideshow_duration') ?? Preferences.defaultSlideshowDurationMs;
  }

  set slideshowDurationMs(int durationMs) {
    _prefs.setInt('viewer.slideshow_duration', durationMs);
  }

  Rect get windowBounds {
    try {
      var bounds = _prefs.getString('bounds');
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

  set windowBounds(Rect rc) {
    _prefs.setString('bounds',
        '${rc.left.toStringAsFixed(1)},${rc.top.toStringAsFixed(1)},${rc.right.toStringAsFixed(1)},${rc.bottom.toStringAsFixed(1)}');
  }
}

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OverlayLevel {
  none,
  file,
  image,
  exif,
}

enum SortType {
  alphabetical,
  chronological,
}

class Preferences extends ChangeNotifier {
  static OverlayLevel get defaultOverlayLevel {
    return OverlayLevel.image;
  }

  static SortType get defaultSortType {
    return SortType.chronological;
  }

  static bool get defaultSortReversed {
    return false;
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
    final level =
        _prefs.getInt('overlayLevel') ?? Preferences.defaultOverlayLevel.index;
    return OverlayLevel.values[level];
  }

  set overlayLevel(OverlayLevel level) {
    _prefs.setInt('overlayLevel', level.index);
  }

  SortType get sortType {
    final type =
        _prefs.getInt('sort.type') ?? Preferences.defaultSortType.index;
    return SortType.values[type];
  }

  set sortType(SortType type) {
    _prefs.setInt('sort.type', type.index);
  }

  bool get sortReversed {
    return _prefs.getBool('sort.reversed') ?? Preferences.defaultSortReversed;
  }

  set sortReversed(bool reversed) {
    _prefs.setBool('sort.reversed', reversed);
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

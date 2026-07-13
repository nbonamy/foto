import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:foto/model/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Preferences> preferencesWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final preferences = Preferences();
    await preferences.init();
    return preferences;
  }

  test('invalid enum values fall back to defaults', () async {
    final preferences = await preferencesWith({
      'viewer.overlayLevel': 999,
      'browser.sort.criteria': -1,
    });

    expect(preferences.overlayLevel, Preferences.defaultOverlayLevel);
    expect(preferences.sortCriteria, Preferences.defaultSortCriteria);
  });

  test('invalid slideshow duration falls back to the default', () async {
    final preferences = await preferencesWith({
      'viewer.slideshow_duration': 0,
    });

    expect(
      preferences.slideshowDurationMs,
      Preferences.defaultSlideshowDurationMs,
    );
  });

  test('preference setters notify only when values change', () async {
    final preferences = await preferencesWith({});
    var notifications = 0;
    preferences.addListener(() => notifications += 1);

    preferences.showInspector = Preferences.defaultShowInspector;
    expect(notifications, 0);

    preferences.showInspector = !Preferences.defaultShowInspector;
    expect(notifications, 1);
  });

  test('invalid saved window bounds fall back to a usable window', () async {
    for (final bounds in <String>[
      'not,bounds',
      '0,0,100,100',
      'NaN,0,800,600',
    ]) {
      final preferences = await preferencesWith({'bounds': bounds});
      expect(
        preferences.windowBounds,
        const Rect.fromLTWH(0, 0, 800, 600),
      );
    }
  });
}

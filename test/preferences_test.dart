import 'package:flutter/material.dart';
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
      'appearance.theme_mode': 999,
      'viewer.overlayLevel': 999,
      'browser.sort.criteria': -1,
    });

    expect(preferences.themeMode, Preferences.defaultThemeMode);
    expect(preferences.overlayLevel, Preferences.defaultOverlayLevel);
    expect(preferences.sortCriteria, Preferences.defaultSortCriteria);
  });

  test('appearance defaults to system and restores a saved mode', () async {
    expect((await preferencesWith({})).themeMode, ThemeMode.system);

    final preferences = await preferencesWith({
      'appearance.theme_mode': ThemeMode.dark.index,
    });
    expect(preferences.themeMode, ThemeMode.dark);
  });

  test('appearance changes persist and notify only once', () async {
    final preferences = await preferencesWith({});
    var notifications = 0;
    preferences.addListener(() => notifications += 1);

    preferences.themeMode = ThemeMode.system;
    expect(notifications, 0);

    preferences.themeMode = ThemeMode.dark;
    expect(notifications, 1);
    expect(preferences.themeMode, ThemeMode.dark);

    final stored = await SharedPreferences.getInstance();
    expect(
      stored.getInt('appearance.theme_mode'),
      ThemeMode.dark.index,
    );
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

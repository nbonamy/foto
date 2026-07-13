import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('instant fullscreen covers and then restores the macos menu bar level',
      () async {
    final source =
        await File('macos/Runner/MainFlutterWindow.swift').readAsString();

    expect(source, contains('level: level'));
    expect(
      source,
      contains(
        'level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)',
      ),
    );
    expect(source, contains('level = state.level'));
  });
}

import 'dart:io';

import 'package:flutter/services.dart';

class PlatformKeyboard {
  static bool isPrevious(RawKeyEvent event) {
    return event.isKeyPressed(LogicalKeyboardKey.arrowLeft) ||
        event.isKeyPressed(LogicalKeyboardKey.arrowUp);
  }

  static bool isNext(RawKeyEvent event) {
    return event.isKeyPressed(LogicalKeyboardKey.arrowRight) ||
        event.isKeyPressed(LogicalKeyboardKey.arrowDown);
  }

  static bool isDelete(RawKeyEvent event) {
    if (Platform.isMacOS) {
      return event.isKeyPressed(LogicalKeyboardKey.backspace) &&
          event.isMetaPressed;
    } else {
      return false;
    }
  }

  static bool isExit(RawKeyEvent event) {
    return event.physicalKey == PhysicalKeyboardKey.escape ||
        event.physicalKey == PhysicalKeyboardKey.enter;
  }
}

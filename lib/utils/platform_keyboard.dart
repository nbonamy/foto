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

  static bool isEscape(RawKeyEvent event) {
    return event.physicalKey == PhysicalKeyboardKey.escape;
  }

  static bool isEnter(RawKeyEvent event) {
    return event.physicalKey == PhysicalKeyboardKey.enter;
  }
}

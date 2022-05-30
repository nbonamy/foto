import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlatformKeyboard {
  static bool isSelectAll(RawKeyEvent event) {
    return event.isKeyPressed(LogicalKeyboardKey.keyA) &&
        commandModifierPressed(event);
  }

  static bool isCopy(RawKeyEvent event) {
    return event.isKeyPressed(LogicalKeyboardKey.keyC) &&
        commandModifierPressed(event);
  }

  static bool isPaste(RawKeyEvent event) {
    return event.isKeyPressed(LogicalKeyboardKey.keyV) &&
        commandModifierPressed(event);
  }

  static bool isPrevious(RawKeyEvent event) {
    return event.isKeyPressed(LogicalKeyboardKey.arrowLeft) ||
        event.isKeyPressed(LogicalKeyboardKey.arrowUp);
  }

  static bool isNext(RawKeyEvent event) {
    return event.isKeyPressed(LogicalKeyboardKey.arrowRight) ||
        event.isKeyPressed(LogicalKeyboardKey.arrowDown);
  }

  static bool isDelete(RawKeyEvent event) {
    return event.isKeyPressed(LogicalKeyboardKey.backspace) &&
        commandModifierPressed(event);
  }

  static bool isEscape(RawKeyEvent event) {
    return event.physicalKey == PhysicalKeyboardKey.escape;
  }

  static bool isEnter(RawKeyEvent event) {
    return event.physicalKey == PhysicalKeyboardKey.enter ||
        event.physicalKey == PhysicalKeyboardKey.numpadEnter;
  }

  static bool selectionExtensionModifierPressed(RawKeyEvent event) {
    return Platform.isIOS ? event.isMetaPressed : event.isControlPressed;
  }

  static bool commandModifierPressed(RawKeyEvent event) {
    if (metaIsCommandModifier()) {
      return event.isMetaPressed;
    } else {
      return event.isControlPressed;
    }
  }

  static bool metaIsCommandModifier() {
    return Platform.isMacOS;
  }

  static bool ctrlIsCommandModifier() {
    return !metaIsCommandModifier();
  }

  static SingleActivator commandActivator(LogicalKeyboardKey key) {
    return SingleActivator(
      key,
      meta: PlatformKeyboard.metaIsCommandModifier(),
      control: PlatformKeyboard.ctrlIsCommandModifier(),
    );
  }
}

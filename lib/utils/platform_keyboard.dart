import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlatformKeyboard {
  static bool isPrevious(KeyEvent event) {
    return event is! KeyUpEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.bracketLeft) &&
        !commandModifierPressed(event);
  }

  static bool isNext(KeyEvent event) {
    return event is! KeyUpEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.bracketRight) &&
        !commandModifierPressed(event);
  }

  static bool isEscape(KeyEvent event) {
    return event.physicalKey == PhysicalKeyboardKey.escape;
  }

  static bool isEnter(KeyEvent event) {
    return event.physicalKey == PhysicalKeyboardKey.enter ||
        event.physicalKey == PhysicalKeyboardKey.numpadEnter;
  }

  static bool selectionExtensionModifierPressed(KeyEvent event) {
    return Platform.isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;
  }

  static bool commandModifierPressed(KeyEvent event) {
    if (metaIsCommandModifier()) {
      return HardwareKeyboard.instance.isMetaPressed;
    } else {
      return HardwareKeyboard.instance.isControlPressed;
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

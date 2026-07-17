import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/platform_keyboard.dart';

typedef MenuActionController = StreamController<MenuAction>;
typedef MenuActionStream = Stream<MenuAction>;

enum MenuAction {
  fileRefresh,
  fileRename,
  editSelectAll,
  editCopy,
  imageCopy,
  editPaste,
  editPasteMove,
  editDelete,
  imageView,
  imageFindSimilar,
  imageCompare,
  imageRotate90cw,
  imageRotate90ccw,
  imageRotate180,
  viewInspector,
}

class MenuUtils {
  static SingleActivator cmdShortcut(LogicalKeyboardKey key) {
    return SingleActivator(
      key,
      control: PlatformKeyboard.ctrlIsCommandModifier(),
      meta: PlatformKeyboard.metaIsCommandModifier(),
    );
  }

  static SingleActivator cmdShiftShortcut(LogicalKeyboardKey key) {
    return SingleActivator(
      key,
      shift: true,
      control: PlatformKeyboard.ctrlIsCommandModifier(),
      meta: PlatformKeyboard.metaIsCommandModifier(),
    );
  }
}

mixin MenuHandler {
  StreamSubscription<MenuAction>? _menuSubscription;

  void initMenuSubscription(MenuActionStream stream) {
    _menuSubscription = stream.listen((event) => onMenuAction(event));
  }

  void cancelMenuSubscription() {
    _menuSubscription?.cancel();
  }

  void onMenuAction(MenuAction action) {
    throw Exception(['Not implemented. You need to override.']);
  }
}

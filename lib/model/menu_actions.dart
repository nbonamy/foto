import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/utils/platform_keyboard.dart';

typedef MenuActionController = StreamController<MenuAction>;
typedef MenuActionStream = Stream<MenuAction>;

enum MenuAction {
  fileRefresh,
  fileRename,
  editSelectAll,
  editCopy,
  editPaste,
  editDelete,
  imageView,
  imageRotate90cw,
  imageRotate90ccw,
  imageRotate180,
}

class MenuUtils {
  static SingleActivator cmdShortcut(LogicalKeyboardKey key) {
    return SingleActivator(
      key,
      control: PlatformKeyboard.ctrlIsCommandModifier(),
      meta: PlatformKeyboard.metaIsCommandModifier(),
    );
  }
}

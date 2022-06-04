import 'dart:async';

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

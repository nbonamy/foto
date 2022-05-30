import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:foto/browser/thumbnail.dart';
import 'package:foto/components/context_menu.dart' as ctxm;
import 'package:foto/components/selectable.dart';
import 'package:foto/utils/file.dart';
import 'package:foto/utils/media.dart';
import 'package:foto/utils/platform_keyboard.dart';
import 'package:foto/model/preferences.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ImageGallery extends StatefulWidget {
  final String path;
  final Function executeItem;
  final BuildContext navigatorContext;
  final ScrollController scrollController;

  const ImageGallery({
    Key? key,
    required this.path,
    required this.navigatorContext,
    required this.executeItem,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  List<FileSystemEntity>? _files;
  final _elements = <SelectableElement>{};
  List<String> _selection = [];
  bool _extendSelection = false;
  StreamSubscription<FileSystemEvent>? _dirSubscription;
  final FocusNode _focusNode = FocusNode();
  String? _fileBeingRenamed;
  Offset? _dragSelectOrig;
  Rect? _dragSelectRect;
  List<String> _dragSelection = [];

  @override
  void initState() {
    _watchDir();
    Preferences.of(context).addListener(() {
      _files = null;
    });
    super.initState();
  }

  @override
  void dispose() {
    _dirSubscription?.cancel();
    _dirSubscription = null;
    super.dispose();
  }

  void _watchDir() {
    // watcher
    _dirSubscription?.cancel();
    _dirSubscription = Directory(widget.path).watch().listen((event) {
      List<String> selection = [];
      for (var file in _selection) {
        if (File(file).existsSync()) {
          selection.add(file);
        }
      }
      setState(() {
        _files = null;
        _selection = selection;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // get files
    Preferences prefs = Preferences.of(context);
    _files ??= Media.getMediaFiles(
      widget.path,
      includeDirs: prefs.showFolders,
      sortType: prefs.sortType,
      sortReversed: prefs.sortReversed,
    );

    // merge selections
    var selection = _mergeSelections(_selection, _dragSelection);

    // focus for keyboard listener
    return Focus(
      focusNode: _focusNode,
      debugLabel: 'gallery',
      //onFocusChange: (hasFocus) {
      //  if (hasFocus) debugPrint('gallery');
      //},
      onKey: (_, event) {
        if (PlatformKeyboard.isSelectAll(event)) {
          _selectAll();
          return KeyEventResult.handled;
        } else if (PlatformKeyboard.isDelete(event) && _selection.isNotEmpty) {
          FileUtils.confirmDelete(context, _selection);
          return KeyEventResult.handled;
        } else if (PlatformKeyboard.isCopy(event)) {
          _copyToClipboard();
          return KeyEventResult.handled;
        } else if (PlatformKeyboard.isPaste(event)) {
          _pasteFromClipboard();
          return KeyEventResult.handled;
        }

        // default
        _extendSelection = event.isControlPressed || event.isMetaPressed;
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleTap,
        onPanDown: _handlePanDown,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Stack(
          children: [
            GridView.extent(
              shrinkWrap: true,
              controller: widget.scrollController,
              maxCrossAxisExtent: Thumbnail.thumbnailWidth(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              padding: const EdgeInsets.all(16),
              childAspectRatio: Thumbnail.aspectRatio(),
              children: _files!.map<Widget>((file) {
                return GestureDetector(
                  onTapDown: (_) {
                    _focusNode.requestFocus();
                    setState(() {
                      if (!_extendSelection) {
                        _selection = [];
                      }
                      _selection.add(file.path);
                      _fileBeingRenamed = null;
                    });
                  },
                  onDoubleTap: () {
                    _focusNode.requestFocus();
                    _handleDoubleTap(file);
                  },
                  child: ctxm.ContextMenu(
                    menu: ctxm.Menu(
                      items: [
                        ctxm.MenuItem(
                          label: AppLocalizations.of(context)!.view,
                          onClick: (_) => _handleDoubleTap(file),
                        ),
                        ctxm.MenuItem(
                          label: AppLocalizations.of(context)!.rename,
                          disabled: _selection.length != 1,
                          onClick: (_) => setState(() {
                            _fileBeingRenamed = file.path;
                          }),
                        ),
                        ctxm.MenuItem.separator(),
                        ctxm.MenuItem(
                          label: AppLocalizations.of(context)!.delete,
                          onClick: (_) =>
                              FileUtils.confirmDelete(context, _selection),
                        ),
                      ],
                    ),
                    onBeforeShowMenu: () {
                      if (_selection.contains(file.path) == false) {
                        setState(() {
                          _selection = [file.path];
                        });
                        return true;
                      }
                      return false;
                    },
                    child: Selectable(
                      id: file.path,
                      onMountElement: _elements.add,
                      onUnmountElement: _elements.remove,
                      child: Thumbnail(
                        path: file.path,
                        folder: file is Directory,
                        selected: selection.contains(file.path),
                        rename: _fileBeingRenamed == file.path,
                        onRenamed: (file, newName) {
                          setState(() {
                            _fileBeingRenamed = null;
                            if (newName != null) {
                              FileUtils.tryRename(file, newName);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            _dragSelectRect == null
                ? Container()
                : Positioned(
                    left: _dragSelectRect?.left,
                    top: _dragSelectRect?.top,
                    width: _dragSelectRect?.width,
                    height: _dragSelectRect?.height,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(64, 170, 170, 170),
                        border: Border.all(
                          color: const Color.fromARGB(255, 170, 170, 170),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _handleTap() {
    _focusNode.requestFocus();
    setState(() {
      _selection = [];
      _fileBeingRenamed = null;
    });
  }

  void _handleDoubleTap(FileSystemEntity file) {
    if (file is Directory) {
      widget.executeItem(folder: file.path);
    } else {
      if (!_selection.contains(file.path)) {
        setState(() {
          _selection = [file.path];
        });
      }
      widget.executeItem(
        images: _files!.whereType<File>().map((f) => f.path).toList(),
        index: _files!.indexOf(file),
      );
    }
  }

  void _handlePanDown(DragDownDetails details) {
    setState(() {
      if (_extendSelection == false) {
        _selection = [];
      }
      _dragSelectOrig = details.localPosition;
      _dragSelectRect = Rect.fromLTWH(
        _dragSelectOrig!.dx,
        _dragSelectOrig!.dy,
        0,
        0,
      );
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _dragSelection = [];
    _dragSelectRect = Rect.fromLTRB(
      min(_dragSelectOrig!.dx, details.localPosition.dx),
      min(_dragSelectOrig!.dy, details.localPosition.dy),
      max(_dragSelectOrig!.dx, details.localPosition.dx),
      max(_dragSelectOrig!.dy, details.localPosition.dy),
    );
    final ancestor = context.findRenderObject();
    for (SelectableElement item in _elements) {
      if (item.isIn(ancestor, _dragSelectRect!)) {
        _dragSelection.add(item.widget.id);
      }
    }
    setState(() {});
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _selection = _mergeSelections(_selection, _dragSelection);
      _dragSelectRect = null;
      _dragSelection = [];
    });
  }

  List<String> _mergeSelections(List<String> orig, List<String> updates) {
    List<String> updated = List.from(orig);
    for (String update in updates) {
      if (updated.contains(update)) {
        updated.remove(update);
      } else {
        updated.add(update);
      }
    }
    return updated;
  }

  void _selectAll() {
    List<String> selection = [];
    for (var file in _files!) {
      if (file is File) {
        selection.add(file.path);
      }
    }
    setState(() {
      _selection = selection;
    });
  }

  void _copyToClipboard() {
    Pasteboard.writeFiles(_selection);
  }

  void _pasteFromClipboard() {
    Pasteboard.files().then((files) {
      FileUtils.tryCopy(context, files, widget.path);
    });
  }
}

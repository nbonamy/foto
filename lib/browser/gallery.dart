import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:foto/browser/thumbnail.dart';
import 'package:foto/components/context_menu.dart' as ctxm;
import 'package:foto/components/selectable.dart';
import 'package:foto/model/media.dart';
import 'package:foto/utils/database.dart';
import 'package:foto/utils/file.dart';
import 'package:foto/utils/image_utils.dart';
import 'package:foto/utils/media_utils.dart';
import 'package:foto/utils/platform_keyboard.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/utils/platform_utils.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

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
  final MediaDb _mediaDb = MediaDb();

  List<MediaItem>? _items;
  String? _fileBeingRenamed;

  final _elements = <SelectableElement>{};
  List<String> _selection = [];
  bool _extendSelection = false;

  StreamSubscription<FileSystemEvent>? _dirSubscription;

  final FocusNode _focusNode = FocusNode();

  Offset? _dragSelectOrig;
  Rect? _dragSelectRect;
  List<String> _dragSelection = [];

  static const String photoshopBundleId = 'com.adobe.Photoshop';
  String? _photoshopPath;

  @override
  void initState() {
    _watchDir();
    Preferences.of(context).addListener(() {
      _items = null;
    });
    PlatformUtils.bundlePathForIdentifier(photoshopBundleId).then((value) {
      _photoshopPath = value;
    });
    super.initState();
  }

  String? get photoshopName {
    return _photoshopPath == null
        ? null
        : p.basenameWithoutExtension(_photoshopPath!);
  }

  @override
  void dispose() {
    _stopWatchDir();
    super.dispose();
  }

  void _stopWatchDir() {
    _dirSubscription?.cancel();
    _dirSubscription = null;
  }

  void _watchDir() {
    // watcher
    _stopWatchDir();
    _dirSubscription = Directory(widget.path).watch().listen((event) {
      List<String> selection = [];
      for (var file in _selection) {
        if (File(file).existsSync()) {
          selection.add(file);
        }
      }
      setState(() {
        _items = null;
        _selection = selection;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    print('build');
    // get files
    if (_items == null) {
      Preferences prefs = Preferences.of(context);
      _items = MediaUtils.getMediaFiles(
        widget.path,
        includeDirs: prefs.showFolders,
        sortType: prefs.sortType,
        sortReversed: prefs.sortReversed,
      );
    }

    // merge selections
    var selection = _mergeSelections(_selection, _dragSelection);

    // focus for keyboard listener
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
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
        } else if (PlatformKeyboard.isRefresh(event)) {
          _refresh();
          return KeyEventResult.handled;
        } else if (PlatformKeyboard.isRotate90CW(event)) {
          _rotateSelection(ImageTransformation.rotate90CW);
          return KeyEventResult.handled;
        } else if (PlatformKeyboard.isRotate90CCW(event)) {
          _rotateSelection(ImageTransformation.rotate90CCW);
          return KeyEventResult.handled;
          /*} else if (PlatformKeyboard.isEnter(event) &&
            _selection.length == 1 &&
            _fileBeingRenamed == null) {
          setState(() {
            _fileBeingRenamed = _selection[0];
          });
          return KeyEventResult.handled;*/
        }

        // default
        _extendSelection =
            PlatformKeyboard.selectionExtensionModifierPressed(event);
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleTap,
        onPanDown: _handlePanDown,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        behavior: HitTestBehavior.translucent,
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
              children: _items!.map<Widget>((media) {
                return GestureDetector(
                  onTapDown: (_) {
                    _focusNode.requestFocus();
                    setState(() {
                      if (!_extendSelection) {
                        _selection = [];
                      }
                      _selection.add(media.path);
                      _fileBeingRenamed = null;
                    });
                  },
                  onDoubleTap: () {
                    _focusNode.requestFocus();
                    _handleDoubleTap(media);
                  },
                  child: _getContextMenu(
                    context,
                    media: media,
                    child: Selectable(
                      id: media.path,
                      onMountElement: _elements.add,
                      onUnmountElement: _elements.remove,
                      child: ValueListenableBuilder<int>(
                        valueListenable: media.updateCounter,
                        builder: (context, value, child) => Thumbnail(
                          key: media.key,
                          media: media,
                          selected: selection.contains(media.path),
                          rename: _fileBeingRenamed == media.path,
                          onRenamed: (file, newName) {
                            _fileBeingRenamed = null;
                            if (newName != null && newName != '') {
                              FileUtils.tryRename(file, newName);
                            }
                            try {
                              setState(() {});
                            } catch (_) {}
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            _getSelectionRect(),
          ],
        ),
      ),
    );
  }

  Widget _getContextMenu(
    BuildContext context, {
    required MediaItem media,
    required Widget child,
  }) {
    return ctxm.ContextMenu(
      menu: ctxm.Menu(
        items: [
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.view,
            onClick: (_) => _handleDoubleTap(media),
          ),
          ctxm.MenuItem(
              label: _photoshopPath == null
                  ? AppLocalizations.of(context)!.edit
                  : AppLocalizations.of(context)!.edit_with(photoshopName!),
              disabled: _photoshopPath == null,
              onClick: (_) => PlatformUtils.openFilesWithBundleIdentifier(
                  _selection, photoshopBundleId)),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.rename,
            disabled: _selection.length != 1,
            onClick: (_) => setState(() {
              _fileBeingRenamed = media.path;
            }),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.copy,
            disabled: _selection.isEmpty,
            onClick: (_) => _copyToClipboard(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.delete,
            onClick: (_) => FileUtils.confirmDelete(context, _selection),
          ),
        ],
      ),
      onBeforeShowMenu: () {
        if (_selection.contains(media.path) == false) {
          setState(() {
            _selection = [media.path];
          });
          return true;
        }
        return false;
      },
      child: child,
    );
  }

  Widget _getSelectionRect() {
    return _dragSelectRect == null
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
          );
  }

  void _refresh() async {
    for (var item in _items!) {
      await item.evictFromCache();
    }
    setState(() {
      _items = null;
    });
  }

  void _handleTap() {
    _focusNode.requestFocus();
    setState(() {
      _selection = [];
      _fileBeingRenamed = null;
    });
  }

  void _handleDoubleTap(MediaItem media) {
    if (!media.isFile()) {
      widget.executeItem(folder: media.path);
    } else {
      if (!_selection.contains(media.path)) {
        setState(() {
          _selection = [media.path];
        });
      }
      List<String> images =
          _items!.where((m) => m.isFile()).map((m) => m.path).toList();
      widget.executeItem(
        images: images,
        index: images.indexOf(media.path),
      );
    }
  }

  void _handlePanDown(DragDownDetails details) {
    // do not start if item tap
    Rect rc =
        Rect.fromLTWH(details.localPosition.dx, details.localPosition.dy, 0, 0);
    final ancestor = context.findRenderObject();
    for (SelectableElement item in _elements) {
      if (item.isIn(ancestor, rc)) {
        return;
      }
    }

    setState(() {
      if (_extendSelection == false) {
        _selection = [];
      }
      _dragSelectOrig = details.localPosition;
      _dragSelectRect = rc;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragSelectOrig == null) {
      return;
    }
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
    _focusNode.requestFocus();
    if (_dragSelectOrig == null) {
      return;
    }
    setState(() {
      _selection = _mergeSelections(_selection, _dragSelection);
      _dragSelectOrig = null;
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
    for (var item in _items!) {
      if (item.isFile()) {
        selection.add(item.path);
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

  void _rotateSelection(ImageTransformation transformation) async {
    _stopWatchDir();
    for (var filepath in _selection) {
      bool rc = await ImageUtils.transformImage(filepath, transformation);
      if (rc && _items != null) {
        for (var item in _items!) {
          if (item.path == filepath) {
            item.evictFromCache();
            break;
          }
        }
      }
    }
    _watchDir();
  }
}

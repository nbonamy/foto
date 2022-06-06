import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/browser/thumbnail.dart';
import 'package:foto/components/context_menu.dart' as ctxm;
import 'package:foto/components/selectable.dart';
import 'package:foto/model/media.dart';
import 'package:foto/model/menu_actions.dart';
import 'package:foto/model/selection.dart';
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
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class ImageGallery extends StatefulWidget {
  final String path;
  final Function executeItem;
  final BuildContext navigatorContext;
  final ScrollController scrollController;
  final MenuActionStream menuActionStream;
  final List<String>? initialSelection;

  const ImageGallery({
    Key? key,
    required this.path,
    required this.navigatorContext,
    required this.executeItem,
    required this.scrollController,
    required this.menuActionStream,
    this.initialSelection,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  final MediaDb _mediaDb = MediaDb();

  List<MediaItem>? _items;
  String? _fileBeingRenamed;

  final _elements = <SelectableElement>{};
  bool _extendSelection = false;

  StreamSubscription<FileSystemEvent>? _dirSubscription;
  StreamSubscription<MenuAction>? _menuSubscription;

  final FocusNode _focusNode = FocusNode();
  late AutoScrollController _autoScrollController;

  Offset? _dragSelectOrig;
  Rect? _dragSelectRect;
  List<String> _dragSelection = [];

  static const String photoshopBundleId = 'com.adobe.Photoshop';
  String? _photoshopPath;

  String? get photoshopName {
    return _photoshopPath == null
        ? null
        : p.basenameWithoutExtension(_photoshopPath!);
  }

  @override
  void initState() {
    _watchDir();
    _initSelection();
    _findPhotoshop();
    _subscribeToMenu();
    _subscribeToSelection();
    _subscribeToPreferences();
    _initAutoScrollController();
    super.initState();
  }

  void _findPhotoshop() {
    PlatformUtils.bundlePathForIdentifier(photoshopBundleId).then((value) {
      _photoshopPath = value;
    });
  }

  void _subscribeToPreferences() {
    Preferences.of(context).addListener(() {
      _items = null;
    });
  }

  void _subscribeToMenu() {
    _menuSubscription =
        widget.menuActionStream.listen((event) => _onMenuAction(event));
  }

  void _subscribeToSelection() {
    SelectionModel.of(context).addListener(() {
      Selection selection = SelectionModel.of(context).get;
      if (selection.length == 1) {
        int index = _items!.indexWhere((it) => it.path == selection[0]);
        if (index != -1) {
          _autoScrollController.scrollToIndex(index);
        }
      }
    });
  }

  void _initSelection() {
    if (widget.initialSelection != null) {
      SelectionModel.of(context).set(
        widget.initialSelection!,
        notify: false,
      );
    } else {
      SelectionModel.of(context).clear(
        notify: false,
      );
    }
  }

  void _initAutoScrollController() {
    _autoScrollController = AutoScrollController(
      viewportBoundaryGetter: () =>
          Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
      axis: Axis.vertical,
    );
  }

  @override
  void dispose() {
    _stopWatchDir();
    _menuSubscription?.cancel();
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
      // first evict modified images
      if (_items != null) {
        for (var item in _items!) {
          item.checkForModification();
        }
      }

      // now restore selection with still existing files
      List<String> selection = [];
      for (var file in SelectionModel.of(context).get) {
        if (File(file).existsSync()) {
          selection.add(file);
        }
      }
      setState(() {
        _items = null;
        SelectionModel.of(context).set(selection);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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

    // focus for keyboard listener
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      debugLabel: 'gallery',
      //onFocusChange: (hasFocus) {
      //  if (hasFocus) debugPrint('gallery');
      //},
      onKey: (_, event) {
        if (_fileBeingRenamed == null) {
          if (event.isKeyPressed(LogicalKeyboardKey.arrowRight) &&
              !PlatformKeyboard.commandModifierPressed(event)) {
            _selectNext();
            return KeyEventResult.handled;
          }
          if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft) &&
              !PlatformKeyboard.commandModifierPressed(event)) {
            _selectPrevious();
            return KeyEventResult.handled;
          }
        }

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
            Consumer<SelectionModel>(
              builder: (context, selectionModel, child) {
                // merge selections
                var selection =
                    _mergeSelections(selectionModel.get, _dragSelection);

                return GridView.extent(
                  shrinkWrap: true,
                  controller: _autoScrollController,
                  maxCrossAxisExtent: Thumbnail.thumbnailWidth(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  padding: const EdgeInsets.all(16),
                  childAspectRatio: Thumbnail.aspectRatio(),
                  children: _items!.map<Widget>((media) {
                    return AutoScrollTag(
                      key: Key(media.path),
                      index: _items!.indexOf(media),
                      controller: _autoScrollController,
                      child: GestureDetector(
                        onTapDown: (_) {
                          _focusNode.requestFocus();
                          setState(() {
                            if (_extendSelection) {
                              selectionModel.add(media.path);
                            } else {
                              selectionModel.set([media.path]);
                            }
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
                                onRenamed: _onFileRenamed,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
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
    Selection selection = SelectionModel.of(context).get;
    return ctxm.ContextMenu(
      menu: ctxm.Menu(
        items: [
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.menuImageView,
            onClick: (_) => _handleDoubleTap(media),
          ),
          ctxm.MenuItem(
              label: _photoshopPath == null
                  ? AppLocalizations.of(context)!.edit
                  : AppLocalizations.of(context)!.edit_with(photoshopName!),
              disabled: _photoshopPath == null,
              onClick: (_) => PlatformUtils.openFilesWithBundleIdentifier(
                  SelectionModel.of(context).get, photoshopBundleId)),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.menuFileRename,
            disabled: selection.length != 1,
            onClick: (_) => _rename(media.path),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.menuEditCopy,
            disabled: selection.isEmpty,
            onClick: (_) => _copyToClipboard(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.menuEditDelete,
            onClick: (_) => _delete(SelectionModel.of(context).get),
          ),
        ],
      ),
      onBeforeShowMenu: () {
        SelectionModel selectionModel = SelectionModel.of(context);
        if (selectionModel.contains(media.path) == false) {
          setState(() {
            selectionModel.set([media.path]);
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

  void _onMenuAction(MenuAction action) {
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    Selection selection = SelectionModel.of(context).get;
    switch (action) {
      case MenuAction.fileRefresh:
        _refresh();
        break;
      case MenuAction.fileRename:
        if (selection.length == 1) {
          _rename(selection[0]);
        }
        break;
      case MenuAction.editSelectAll:
        _selectAll();
        break;
      case MenuAction.editCopy:
        _copyToClipboard();
        break;
      case MenuAction.editPaste:
        _pasteFromClipboard();
        break;
      case MenuAction.editDelete:
        _delete(selection);
        break;
      case MenuAction.imageView:
        if (selection.isNotEmpty) {
          var item = _items?.firstWhere((it) => it.path == selection[0]);
          if (item != null) {
            _handleDoubleTap(item);
          }
        } else if (_items != null) {
          for (var item in _items!) {
            if (item.isFile()) {
              _handleDoubleTap(item);
              break;
            }
          }
        }
        break;
      case MenuAction.imageRotate90cw:
        _rotateSelection(ImageTransformation.rotate90CW);
        break;
      case MenuAction.imageRotate90ccw:
        _rotateSelection(ImageTransformation.rotate90CCW);
        break;
      case MenuAction.imageRotate180:
        _rotateSelection(ImageTransformation.rotate180);
        break;
      default:
        break;
    }
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
      SelectionModel.of(context).clear();
      _fileBeingRenamed = null;
    });
  }

  void _handleDoubleTap(MediaItem media) {
    if (!media.isFile()) {
      widget.executeItem(folder: media.path);
    } else {
      Selection selection = SelectionModel.of(context).get;
      if (!selection.contains(media.path)) {
        setState(() {
          SelectionModel.of(context).set([media.path]);
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
        SelectionModel.of(context).clear();
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
      SelectionModel selectionModel = SelectionModel.of(context);
      selectionModel.set(_mergeSelections(selectionModel.get, _dragSelection));
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

  int _selectionIndex() {
    SelectionModel selectionModel = SelectionModel.of(context);
    if (selectionModel.get.length != 1) {
      return -1;
    } else {
      return _items!.indexWhere((item) => item.path == selectionModel.get[0]);
    }
  }

  void _selectNext() {
    if (_items != null) {
      int index = _selectionIndex();
      index = min(index + 1, _items!.length - 1);
      SelectionModel.of(context).set([_items![index].path]);
      _autoScrollController.scrollToIndex(index,
          preferPosition: AutoScrollPosition.middle);
    }
  }

  void _selectPrevious() {
    if (_items != null) {
      int index = _selectionIndex();
      index = max(index - 1, 0);
      SelectionModel.of(context).set([_items![index].path]);
      _autoScrollController.scrollToIndex(index,
          preferPosition: AutoScrollPosition.middle);
    }
  }

  void _rename(String path) {
    setState(() {
      _fileBeingRenamed = path;
    });
  }

  void _onFileRenamed(file, newName) {
    // we are just asked to end editing
    if (newName == null) {
      setState(() {
        _fileBeingRenamed = null;
      });
      return;
    }

    // now do it
    if (newName != '') {
      String? newPath = FileUtils.tryRename(file, newName);
      if (newPath != null) {
        SelectionModel.of(context).set([newPath], notify: false);
      }
    }
  }

  void _selectAll() {
    List<String> selection = [];
    for (var item in _items!) {
      if (item.isFile()) {
        selection.add(item.path);
      }
    }
    setState(() {
      SelectionModel.of(context).set(selection);
    });
  }

  void _copyToClipboard() {
    Selection selection = SelectionModel.of(context).get;
    if (selection.isNotEmpty) {
      Pasteboard.writeFiles(selection);
    }
  }

  void _pasteFromClipboard() {
    Pasteboard.files().then((files) {
      FileUtils.tryCopy(context, files, widget.path);
    });
  }

  void _delete(List<String> paths) {
    if (paths.isNotEmpty) {
      FileUtils.confirmDelete(context, paths);
    }
  }

  void _rotateSelection(ImageTransformation transformation) async {
    _stopWatchDir();
    Selection selection = SelectionModel.of(context).get;
    for (var filepath in selection) {
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

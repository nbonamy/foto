import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../components/context_menu.dart' as ctxm;
import '../components/selectable.dart';
import '../model/media.dart';
import '../model/menu_actions.dart';
import '../model/preferences.dart';
import '../model/selection.dart';
import '../utils/database.dart';
import '../utils/file_utils.dart';
import '../utils/image_utils.dart';
import '../utils/media_utils.dart';
import '../utils/platform_keyboard.dart';
import '../utils/platform_utils.dart';
import 'thumbnail.dart';

class ImageGallery extends StatefulWidget {
  final String path;
  final MediaDb mediaDb;
  final Function executeItem;
  final BuildContext navigatorContext;
  final ScrollController scrollController;
  final MenuActionStream menuActionStream;
  final List<String>? initialSelection;

  const ImageGallery({
    Key? key,
    required this.path,
    required this.mediaDb,
    required this.navigatorContext,
    required this.executeItem,
    required this.scrollController,
    required this.menuActionStream,
    this.initialSelection,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> with MenuHandler {
  List<MediaItem>? _items;
  String? _fileBeingRenamed;

  late Preferences _preferences;

  late SelectionModel _selectionModel;
  final _elements = <SelectableElement>{};
  bool _extendSelection = false;

  StreamSubscription<FileSystemEvent>? _dirSubscription;

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

  Selection get selection {
    return _selectionModel.get;
  }

  @override
  void initState() {
    _watchDir();
    _findPhotoshop();
    _subscribeToMenu();
    _subscribeToSelection();
    _subscribeToPreferences();
    _initAutoScrollController();
    _initSelection();
    super.initState();
  }

  void _findPhotoshop() {
    PlatformUtils.bundlePathForIdentifier(photoshopBundleId).then((value) {
      _photoshopPath = value;
    });
  }

  void _subscribeToPreferences() {
    _preferences = Preferences.of(context);
    _preferences.addListener(_onPrefsChange);
  }

  void _subscribeToMenu() {
    initMenuSubscription(widget.menuActionStream);
  }

  void _subscribeToSelection() {
    _selectionModel = SelectionModel.of(context);
    _selectionModel.addListener(_onSelectionChange);
  }

  void _initSelection() {
    if (widget.initialSelection != null) {
      _selectionModel.set(
        widget.initialSelection!,
        notify: true,
      );
      return;
    } else if (_items != null && _items!.isNotEmpty) {
      for (MediaItem item in _items!) {
        if (item.isFile()) {
          _selectionModel.set(
            [item.path],
            notify: true,
          );
          return;
        }
      }
    }

    // default
    if (_selectionModel.get.isEmpty == false) {
      _selectionModel.clear(
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
    cancelMenuSubscription();
    _preferences.removeListener(_onPrefsChange);
    _selectionModel.removeListener(_onSelectionChange);
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
      // skip
      if (event.type == FileSystemEvent.modify) {
        FileSystemModifyEvent modifyEvent = event as FileSystemModifyEvent;
        if (modifyEvent.contentChanged == false) {
          return;
        }
      }

      // debug
      //print('Directory Watcher event: ${event.type} ${event.path}');

      // first evict modified images
      if (_items != null) {
        for (var item in _items!) {
          item.checkForModification();
        }
      }

      // now restore selection with still existing files
      List<String> selection = [];
      for (var file in selection) {
        if (File(file).existsSync()) {
          selection.add(file);
        }
      }
      setState(() {
        _items = null;
        _selectionModel.set(selection);
      });
    });
  }

  void _onPrefsChange() {
    _items = null;
  }

  void _onSelectionChange() {
    if (_items != null && selection.length == 1) {
      int index = _items!.indexWhere((it) => it.path == selection[0]);
      if (index != -1) {
        _autoScrollController.scrollToIndex(index);
      }
    }
  }

  Future<List<MediaItem>> _getItems() async {
    bool startedEmpty = _items == null;
    _items = _items ??
        await MediaUtils.getMediaFiles(
          widget.mediaDb,
          widget.path,
          includeDirs: _preferences.showFolders,
          sortCriteria: _preferences.sortCriteria,
          sortReversed: _preferences.sortReversed,
        );
    if (startedEmpty) {
      _initSelection();
    }
    Future.delayed(const Duration(milliseconds: 0), () async {
      if (_items == null) return;
      for (MediaItem mediaItem in _items!) {
        if (mediaItem.mediaInfoParsed) continue;
        await mediaItem.getMediaInfo();
      }
    });
    return _items!;
  }

  @override
  Widget build(BuildContext context) {
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
                return FutureBuilder(
                    future: _getItems(),
                    builder: (context, snapshot) {
                      if (_items == null) return const SizedBox();
                      // merge selections
                      var selection =
                          _mergeSelections(selectionModel.get, _dragSelection);
                      return GridView.builder(
                        shrinkWrap: true,
                        controller: _autoScrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: Thumbnail.thumbnailWidth(),
                          mainAxisExtent: Thumbnail.thumbnailHeight(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                        itemCount: _items?.length,
                        itemBuilder: (context, index) {
                          MediaItem media = _items![index];
                          return AutoScrollTag(
                            key: Key(media.path),
                            index: _items!.indexOf(media),
                            controller: _autoScrollController,
                            child: GestureDetector(
                              onTapDown: (_) {
                                _focusNode.requestFocus();
                                _fileBeingRenamed = null;
                                if (_extendSelection) {
                                  selectionModel.add(media.path);
                                } else {
                                  selectionModel.set([media.path]);
                                }
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
                                    builder: (context, value, child) =>
                                        Thumbnail(
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
                        },
                      );
                    });
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
    AppLocalizations t = AppLocalizations.of(context)!;
    return ctxm.ContextMenu(
      menu: ctxm.Menu(
        items: [
          ctxm.MenuItem(
            label: t.menuImageView,
            onClick: (_) => _handleDoubleTap(media),
          ),
          ctxm.MenuItem(
              label:
                  _photoshopPath == null ? t.edit : t.edit_with(photoshopName!),
              disabled: _photoshopPath == null,
              onClick: (_) => PlatformUtils.openFilesWithBundleIdentifier(
                  selection, photoshopBundleId)),
          ctxm.MenuItem(
            label: t.menuFileRename,
            disabled: selection.length != 1,
            onClick: (_) => _rename(media.path),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: t.menuEditCopy,
            disabled: selection.isEmpty,
            onClick: (_) => _copyToClipboard(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: t.menuEditDelete,
            onClick: (_) => _delete(selection),
          ),
        ],
      ),
      onBeforeShowMenu: () {
        SelectionModel selectionModel = _selectionModel;
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
        ? const SizedBox()
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

  @override
  void onMenuAction(MenuAction action) {
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
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
      case MenuAction.editPasteMove:
        _pasteMoveFromClipboard();
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
      _selectionModel.clear();
      _fileBeingRenamed = null;
    });
  }

  void _handleDoubleTap(MediaItem media) {
    if (!media.isFile()) {
      widget.executeItem(folder: media.path);
    } else {
      if (!selection.contains(media.path)) {
        setState(() {
          _selectionModel.set([media.path]);
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
        _selectionModel.clear();
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
      SelectionModel selectionModel = _selectionModel;
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
    SelectionModel selectionModel = _selectionModel;
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
      _selectionModel.set([_items![index].path]);
      _autoScrollController.scrollToIndex(index,
          preferPosition: AutoScrollPosition.middle);
    }
  }

  void _selectPrevious() {
    if (_items != null) {
      int index = _selectionIndex();
      index = max(index - 1, 0);
      _selectionModel.set([_items![index].path]);
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
        _selectionModel.set([newPath], notify: false);
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
      _selectionModel.set(selection);
    });
  }

  void _copyToClipboard() {
    if (selection.isNotEmpty) {
      Pasteboard.writeFiles(selection);
    }
  }

  void _pasteFromClipboard() {
    FileUtils.tryPaste(context, widget.path, false);
  }

  void _pasteMoveFromClipboard() {
    FileUtils.tryPaste(context, widget.path, true);
  }

  void _delete(List<String> paths) {
    if (paths.isNotEmpty) {
      FileUtils.confirmDelete(context, paths);
    }
  }

  void _rotateSelection(ImageTransformation transformation) async {
    _stopWatchDir();
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

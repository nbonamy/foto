import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/l10n/app_localizations.dart';
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
  final MenuActionStream menuActionStream;
  final FocusNode focusNode;
  final List<String>? initialSelection;

  const ImageGallery({
    super.key,
    required this.path,
    required this.mediaDb,
    required this.navigatorContext,
    required this.executeItem,
    required this.menuActionStream,
    required this.focusNode,
    this.initialSelection,
  });

  @override
  State<StatefulWidget> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> with MenuHandler {
  List<MediaItem>? _items;
  Future<List<MediaItem>>? _itemsFuture;
  int _loadGeneration = 0;
  final Map<MediaItem, Future<void>> _captureDateLoading = {};
  final Set<String> _pendingModifiedPaths = {};
  String? _fileBeingRenamed;

  late Preferences _preferences;

  late SelectionModel _selectionModel;
  final _elements = <SelectableElement>{};
  bool _extendSelection = false;

  StreamSubscription<FileSystemEvent>? _dirSubscription;
  Timer? _reloadDebounce;

  late AutoScrollController _autoScrollController;

  FocusNode get _focusNode => widget.focusNode;

  Offset? _dragSelectOrig;
  Rect? _dragSelectRect;
  List<String> _dragSelection = [];

  static const String photoshopBundleId = 'com.adobe.Photoshop';
  String? _photoshopPath;
  bool _selectionInitialized = false;
  late bool _showFolders;
  late SortCriteria _sortCriteria;
  late bool _sortReversed;

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
    super.initState();
    _subscribeToMenu();
    _subscribeToSelection();
    _subscribeToPreferences();
    _initAutoScrollController();
    _initSelection();
    _watchDir();
    _findPhotoshop();
  }

  void _findPhotoshop() {
    PlatformUtils.bundlePathForIdentifier(photoshopBundleId).then((value) {
      if (mounted) {
        setState(() => _photoshopPath = value);
      }
    }).onError((error, stackTrace) {
      debugPrint('Unable to find Photoshop: $error');
    });
  }

  void _subscribeToPreferences() {
    _preferences = Preferences.of(context);
    _showFolders = _preferences.showFolders;
    _sortCriteria = _preferences.sortCriteria;
    _sortReversed = _preferences.sortReversed;
    _preferences.addListener(_onPrefsChange);
  }

  void _subscribeToMenu() {
    initMenuSubscription(widget.menuActionStream);
  }

  void _subscribeToSelection() {
    _selectionModel = SelectionModel.of(context);
  }

  void _initSelection() {
    if (widget.initialSelection != null) {
      _selectionModel.set(
        widget.initialSelection!,
        notify: true,
      );
      _selectionInitialized = true;
      return;
    } else if (_items != null && _items!.isNotEmpty) {
      for (MediaItem item in _items!) {
        if (item.isFile()) {
          _selectionModel.set(
            [item.path],
            notify: true,
          );
          _selectionInitialized = true;
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
    _reloadDebounce?.cancel();
    _stopWatchDir();
    cancelMenuSubscription();
    _preferences.removeListener(_onPrefsChange);
    _autoScrollController.dispose();
    super.dispose();
  }

  void _stopWatchDir() {
    _dirSubscription?.cancel();
    _dirSubscription = null;
  }

  void _watchDir() {
    _stopWatchDir();
    try {
      _dirSubscription = Directory(widget.path).watch().listen((event) {
        unawaited(_handleDirectoryEvent(event));
      }, onError: (Object error, StackTrace stackTrace) {
        debugPrint('Unable to watch ${widget.path}: $error');
      });
    } catch (error) {
      debugPrint('Unable to watch ${widget.path}: $error');
    }
  }

  Future<void> _handleDirectoryEvent(FileSystemEvent event) async {
    // Ignore metadata-only modification events.
    if (event is FileSystemModifyEvent && !event.contentChanged) return;

    final modifiedPaths = <String>{};
    final items = _items;
    if (items != null) {
      final eventPath = p.normalize(p.absolute(event.path));
      var candidates = items
          .where((item) => p.normalize(p.absolute(item.path)) == eventPath)
          .toList(growable: false);

      // Some platforms report a directory-wide modification instead of the
      // individual changed file. Keep that uncommon fallback asynchronous.
      if (candidates.isEmpty &&
          event is FileSystemModifyEvent &&
          (event.path.isEmpty ||
              eventPath == p.normalize(p.absolute(widget.path)))) {
        candidates =
            items.where((item) => item.isFile()).toList(growable: false);
      }
      final modified = await Future.wait(
        candidates.map((item) => item.checkForModification()),
      );
      for (var index = 0; index < candidates.length; index += 1) {
        if (modified[index]) modifiedPaths.add(candidates[index].path);
      }
      _pendingModifiedPaths.addAll(modifiedPaths);
    }

    if (!mounted) return;
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted) return;
      final modifiedPaths = Set<String>.of(_pendingModifiedPaths);
      _pendingModifiedPaths.clear();
      final existingSelection = <String>[];
      final selectedPaths = selection.toList(growable: false);
      for (final path in selectedPaths) {
        if (await FileSystemEntity.type(path) !=
            FileSystemEntityType.notFound) {
          existingSelection.add(path);
        }
      }
      if (!mounted) return;
      _selectionModel.set(existingSelection);
      if (existingSelection.any(modifiedPaths.contains)) {
        _selectionModel.refresh();
      }
      _reloadItems();
    });
  }

  void _onPrefsChange() {
    final reload = _showFolders != _preferences.showFolders ||
        _sortCriteria != _preferences.sortCriteria ||
        _sortReversed != _preferences.sortReversed;
    _showFolders = _preferences.showFolders;
    _sortCriteria = _preferences.sortCriteria;
    _sortReversed = _preferences.sortReversed;
    if (reload && mounted) {
      _reloadItems();
    }
  }

  Future<List<MediaItem>> _getItems() async {
    return _itemsFuture ??= _loadItems();
  }

  Future<List<MediaItem>> _loadItems() async {
    final generation = _loadGeneration;
    final items = await MediaUtils.getMediaFiles(
      widget.mediaDb,
      widget.path,
      includeDirs: _showFolders,
      sortCriteria: _sortCriteria,
      sortReversed: _sortReversed,
    );
    if (!mounted || generation != _loadGeneration) {
      return items;
    }
    _items = items;
    if (!_selectionInitialized) {
      _initSelection();
      _selectionInitialized = true;
    } else {
      final itemPaths = items.map((item) => item.path).toSet();
      _selectionModel.set(
        selection.where(itemPaths.contains).toList(growable: false),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _loadGeneration) {
        unawaited(_loadCaptureDates(items, generation));
      }
    });
    return items;
  }

  Future<void> _loadCaptureDates(
    List<MediaItem> items,
    int generation,
  ) async {
    if (_sortCriteria != SortCriteria.chronological) return;
    var nextIndex = 0;
    Future<void> worker() async {
      while (mounted && generation == _loadGeneration) {
        if (nextIndex >= items.length) return;
        final mediaItem = items[nextIndex++];
        if (mediaItem.captureDateParsed) continue;
        try {
          await _ensureCaptureDate(mediaItem);
        } catch (error) {
          debugPrint(
            'Unable to read capture date for ${mediaItem.path}: $error',
          );
        }
      }
    }

    await Future.wait(
      List.generate(min(4, items.length), (_) => worker()),
    );
    if (!mounted || generation != _loadGeneration || _items == null) return;
    if (_sortCriteria == SortCriteria.chronological) {
      final sorted = List<MediaItem>.of(_items!);
      MediaUtils.sortMediaItems(
        sorted,
        sortCriteria: _sortCriteria,
        sortReversed: _sortReversed,
      );
      if (!listEquals(
        sorted.map((item) => item.path).toList(growable: false),
        _items!.map((item) => item.path).toList(growable: false),
      )) {
        setState(() => _items = sorted);
      }
    }
  }

  Future<void> _ensureCaptureDate(MediaItem mediaItem) async {
    while (!mediaItem.captureDateParsed) {
      final existingLoad = _captureDateLoading[mediaItem];
      if (existingLoad != null) {
        await existingLoad;
        continue;
      }

      final load = mediaItem.getCaptureDate();
      _captureDateLoading[mediaItem] = load;
      try {
        await load;
      } finally {
        if (identical(_captureDateLoading[mediaItem], load)) {
          _captureDateLoading.remove(mediaItem);
        }
      }
    }
  }

  void _reloadItems() {
    if (!mounted) return;
    setState(() {
      _loadGeneration += 1;
      _items = null;
      _itemsFuture = null;
    });
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
      onKeyEvent: (_, event) {
        if (event is KeyUpEvent) {
          _extendSelection =
              PlatformKeyboard.selectionExtensionModifierPressed(event);
          return KeyEventResult.ignored;
        }
        if (_fileBeingRenamed == null) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              !PlatformKeyboard.commandModifierPressed(event)) {
            _selectNext();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
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
            FutureBuilder(
              future: _getItems(),
              builder: (context, snapshot) {
                if (_items == null) return const SizedBox();
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
                    final media = _items![index];
                    return Selector<SelectionModel, bool>(
                      selector: (_, selectionModel) =>
                          selectionModel.contains(media.path),
                      builder: (context, selected, child) {
                        final isSelected = _dragSelection.contains(media.path)
                            ? !selected
                            : selected;
                        return AutoScrollTag(
                          key: Key(media.path),
                          index: index,
                          controller: _autoScrollController,
                          child: Listener(
                            onPointerDown: (event) {
                              if (event.buttons & kPrimaryMouseButton != 0) {
                                _selectFromPointer(media);
                              }
                            },
                            child: GestureDetector(
                              onTap: () {},
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
                                      selected: isSelected,
                                      rename: _fileBeingRenamed == media.path,
                                      onRenamed: _onFileRenamed,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
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
            label: t.menuEditCopyItems,
            disabled: selection.isEmpty,
            onClick: (_) => _copyToClipboard(),
          ),
          ctxm.MenuItem(
            label: t.menuImageCopy,
            disabled: !_canCopyImage,
            onClick: (_) => _copyImageToClipboard(),
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
          selectionModel.set([media.path]);
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
      case MenuAction.imageCopy:
        _copyImageToClipboard();
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
          final matches =
              _items?.where((it) => it.path == selection[0]).toList();
          if (matches != null && matches.isNotEmpty) {
            _handleDoubleTap(matches.first);
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
    final items = _items;
    if (items == null) return;
    for (var item in items) {
      await item.evictFromCache();
    }
    _reloadItems();
  }

  void _handleTap() {
    _focusNode.requestFocus();
    _selectionModel.clear();
    if (_fileBeingRenamed != null) {
      setState(() {
        _fileBeingRenamed = null;
      });
    }
  }

  void _selectFromPointer(MediaItem media) {
    _focusNode.requestFocus();
    if (_fileBeingRenamed != null) {
      setState(() {
        _fileBeingRenamed = null;
      });
    }
    if (_extendSelection) {
      _selectionModel.toggle(media.path);
    } else {
      _selectionModel.set([media.path]);
    }
  }

  void _handleDoubleTap(MediaItem media) {
    if (!media.isFile()) {
      widget.executeItem(folder: media.path);
    } else {
      if (!selection.contains(media.path)) {
        _selectionModel.set([media.path]);
      }
      List<String> images =
          (_items ?? []).where((m) => m.isFile()).map((m) => m.path).toList();
      final index = images.indexOf(media.path);
      if (index < 0) return;
      widget.executeItem(
        images: images,
        index: index,
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
    final updated = orig.toSet();
    for (String update in updates) {
      if (updated.contains(update)) {
        updated.remove(update);
      } else {
        updated.add(update);
      }
    }
    return updated.toList(growable: false);
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
    if (_items != null && _items!.isNotEmpty) {
      int index = _selectionIndex();
      index = min(index + 1, _items!.length - 1);
      _selectionModel.set([_items![index].path]);
      if (_autoScrollController.hasClients) {
        unawaited(_autoScrollController.scrollToIndex(
          index,
          preferPosition: AutoScrollPosition.middle,
        ));
      }
    }
  }

  void _selectPrevious() {
    if (_items != null && _items!.isNotEmpty) {
      int index = _selectionIndex();
      index = max(index - 1, 0);
      _selectionModel.set([_items![index].path]);
      if (_autoScrollController.hasClients) {
        unawaited(_autoScrollController.scrollToIndex(
          index,
          preferPosition: AutoScrollPosition.middle,
        ));
      }
    }
  }

  void _rename(String path) {
    setState(() {
      _fileBeingRenamed = path;
    });
  }

  bool _onFileRenamed(String file, String? newName) {
    // we are just asked to end editing
    if (newName == null) {
      setState(() {
        _fileBeingRenamed = null;
      });
      return true;
    }

    // now do it
    if (newName.trim().isNotEmpty) {
      String? newPath = FileUtils.tryRename(file, newName);
      if (newPath != null) {
        if (_selectionModel.contains(file)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectionModel.contains(file)) {
              _selectionModel.set([newPath]);
            }
          });
        }
        return true;
      }
    }
    return false;
  }

  void _selectAll() {
    if (_items == null) return;
    List<String> selection = [];
    for (var item in _items!) {
      if (item.isFile()) {
        selection.add(item.path);
      }
    }
    _selectionModel.set(selection);
  }

  void _copyToClipboard() {
    if (selection.isNotEmpty) {
      Pasteboard.writeFiles(selection);
    }
  }

  bool get _canCopyImage =>
      selection.length == 1 && MediaUtils.isImage(selection.single);

  Future<void> _copyImageToClipboard() async {
    if (!_canCopyImage) return;
    try {
      await ImageUtils.copyImageToClipboard(selection.single);
    } catch (error) {
      debugPrint('Unable to copy image to clipboard: $error');
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
    final paths = selection.toList(growable: false);
    var changed = false;
    _stopWatchDir();
    try {
      for (var filepath in paths) {
        bool rc = await ImageUtils.transformImage(filepath, transformation);
        if (rc) {
          changed = true;
        }
        if (rc && _items != null) {
          for (var item in _items!) {
            if (item.path == filepath) {
              await item.refresh();
              break;
            }
          }
        }
      }
    } finally {
      if (mounted) {
        if (changed) {
          _selectionModel.refresh();
          _reloadItems();
        }
        _watchDir();
      }
    }
  }
}

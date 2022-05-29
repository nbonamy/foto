import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/browser/thumbnail.dart';
import 'package:foto/components/context_menu.dart' as ctxm;
import 'package:foto/utils/file.dart';
import 'package:foto/utils/media.dart';
import 'package:foto/utils/platform_keyboard.dart';
import 'package:foto/model/preferences.dart';
import 'package:pasteboard/pasteboard.dart';

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
  List<String> _selection = [];
  bool _extendSelection = false;
  StreamSubscription<FileSystemEvent>? _dirSubscription;
  final FocusNode _focusNode = FocusNode();
  String? _fileBeingRenamed;

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

    // focus for keyboard listener
    return Focus(
      focusNode: _focusNode,
      debugLabel: 'gallery',
      //onFocusChange: (hasFocus) {
      //  if (hasFocus) debugPrint('gallery');
      //},
      onKey: (_, event) {
        if (PlatformKeyboard.isDelete(event) && _selection.isNotEmpty) {
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
        onTap: () {
          _focusNode.requestFocus();
          setState(() {
            _selection = [];
            _fileBeingRenamed = null;
          });
        },
        child: GridView.extent(
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
                _onDoubleTap(file);
              },
              child: ctxm.ContextMenu(
                menu: ctxm.Menu(
                  items: [
                    ctxm.MenuItem(
                      label: 'View',
                      onClick: (_) => _onDoubleTap(file),
                    ),
                    ctxm.MenuItem(
                      label: 'Rename',
                      disabled: _selection.length != 1,
                      onClick: (_) => setState(() {
                        _fileBeingRenamed = file.path;
                      }),
                    ),
                    ctxm.MenuItem.separator(),
                    ctxm.MenuItem(
                      label: 'Move to Trash',
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
                child: Thumbnail(
                  path: file.path,
                  folder: file is Directory,
                  selected: _selection.contains(file.path),
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
            );
          }).toList(),
        ),
      ),
    );
  }

  void _onDoubleTap(FileSystemEntity file) {
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

  void _copyToClipboard() {
    Pasteboard.writeFiles(_selection);
  }

  void _pasteFromClipboard() {
    Pasteboard.files().then((files) {
      FileUtils.tryCopy(context, files, widget.path);
    });
  }
}

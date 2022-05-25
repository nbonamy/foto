import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/browser/thumbnail.dart';
import 'package:foto/components/context_menu.dart' as ctxm;
import 'package:foto/model/history.dart';
import 'package:foto/utils/file.dart';
import 'package:foto/utils/media.dart';
import 'package:foto/utils/platform_keyboard.dart';
import 'package:foto/model/preferences.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';

class ImageGallery extends StatefulWidget {
  final ScrollController scrollController;
  final Function viewImages;

  const ImageGallery({
    Key? key,
    required this.viewImages,
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
  FocusNode focusNode = FocusNode();

  HistoryModel get history {
    return Provider.of<HistoryModel>(context, listen: false);
  }

  @override
  void initState() {
    _watchDir();
    history.addListener(() {
      _selection = [];
      _files = null;
      _watchDir();
    });
    Preferences.of(context).addListener(() {
      _files = null;
    });
    super.initState();
  }

  void _watchDir() {
    // watcher
    _dirSubscription?.cancel();
    _dirSubscription = Directory(history.top!).watch().listen((event) {
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
      history.top,
      includeDirs: prefs.showFolders,
      sortType: prefs.sortType,
      sortReversed: prefs.sortReversed,
    );

    // focus for keyboard listener
    return Focus(
      focusNode: focusNode,
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
          focusNode.requestFocus();
          setState(() {
            _selection = [];
          });
        },
        child: GridView.extent(
          shrinkWrap: true,
          controller: widget.scrollController,
          maxCrossAxisExtent: Thumbnail.thumbnailWidth,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          padding: const EdgeInsets.all(16),
          childAspectRatio: Thumbnail.aspectRatio(),
          children: _files!.map<Widget>((file) {
            return InkResponse(
              onTapDown: (_) {
                focusNode.requestFocus();
                setState(() {
                  if (!_extendSelection) {
                    _selection = [];
                  }
                  _selection.add(file.path);
                });
              },
              onDoubleTap: () {
                focusNode.requestFocus();
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
                  }
                },
                child: Thumbnail(
                  path: file.path,
                  folder: file is Directory,
                  selected: _selection.contains(file.path),
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
      history.push(file.path);
    } else {
      if (!_selection.contains(file.path)) {
        setState(() {
          _selection = [file.path];
        });
      }
      widget.viewImages(
        _files!.whereType<File>().map((f) => f.path).toList(),
        _files!.indexOf(file),
      );
    }
  }

  void _copyToClipboard() {
    Pasteboard.writeFiles(_selection);
  }

  void _pasteFromClipboard() {
    var history = Provider.of<HistoryModel>(context, listen: false);
    if (history.top != null) {
      Pasteboard.files().then((files) {
        FileUtils.tryCopy(context, files, history.top!);
      });
    }
  }
}

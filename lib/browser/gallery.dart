import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/browser/thumbnail.dart';
import 'package:foto/model/history.dart';
import 'package:foto/utils/file.dart';
import 'package:foto/utils/media.dart';
import 'package:foto/utils/platform_keyboard.dart';
import 'package:provider/provider.dart';

class ImageGallery extends StatefulWidget {
  final ScrollController scrollController;
  final Function viewImage;

  const ImageGallery({
    Key? key,
    required this.viewImage,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  late List<String> _selection;
  bool _extendSelection = false;
  bool _historyListenedAdded = false;
  StreamSubscription<FileSystemEvent>? _dirSubscription;

  @override
  void initState() {
    _selection = [];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // history
    var history = Provider.of<HistoryModel>(context);
    if (!_historyListenedAdded) {
      _historyListenedAdded = true;
      history.addListener(() {
        setState(() {
          _selection = [];
        });
      });
    }

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
        _selection = selection;
      });
    });

    // get files
    var files = Media.getMediaFiles(history.top, true);

    // focus for keyboard listener
    return Focus(
      autofocus: true,
      onKey: (_, event) {
        if (PlatformKeyboard.isDelete(event)) {
          FileUtils.confirmDelete(context, _selection);
          return KeyEventResult.handled;
        }

        // default
        _extendSelection = event.isControlPressed || event.isMetaPressed;
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
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
          children: files.map<Widget>((file) {
            return InkResponse(
              onTap: () {
                setState(() {
                  if (!_extendSelection) {
                    _selection = [];
                  }
                  _selection.add(file.path);
                });
              },
              onDoubleTap: () {
                if (file is Directory) {
                  history.push(file.path);
                } else {
                  widget.viewImage(file.path);
                }
              },
              child: Thumbnail(
                path: file.path,
                folder: file is Directory,
                selected: _selection.contains(file.path),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/browser/thumbnail.dart';
import 'package:foto/model/history.dart';
import 'package:foto/utils/media.dart';
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
  final FocusNode _focusNode = FocusNode();

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

    // get files
    var files = Media.getMediaFiles(history.top, true);

    // focus for keyboard listener
    FocusScope.of(context).requestFocus(_focusNode);
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        _extendSelection = event.isControlPressed || event.isMetaPressed;
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
    );
  }
}

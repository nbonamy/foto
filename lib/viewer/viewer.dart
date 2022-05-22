import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/utils/preferences.dart';
import 'package:foto/viewer/overlay.dart';

class ImageViewer extends StatefulWidget {
  final List<String> images;
  final int start;
  final Function exit;
  const ImageViewer({
    Key? key,
    required this.images,
    required this.start,
    required this.exit,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late int _index;
  OverlayLevel _overlayLevel = Preferences.defaultOverlayLevel();

  @override
  void initState() {
    _index = max(0, widget.start);
    Preferences.getOverlayLevel().then((value) => setState(() {
          _overlayLevel = value;
        }));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKey: (_, event) {
        if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft) ||
            event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
          setState(() {
            _index = _index == 0 ? widget.images.length - 1 : _index - 1;
          });
        } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight) ||
            event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
          setState(() {
            _index = _index == widget.images.length - 1 ? 0 : _index + 1;
          });
        } else if (event.isKeyPressed(LogicalKeyboardKey.keyI)) {
          var index = _overlayLevel.index;
          index = (index + 1) % OverlayLevel.values.length;
          setState(() {
            _overlayLevel = OverlayLevel.values[index];
            Preferences.saveOverlayLevel(_overlayLevel);
          });
        } else if (event.physicalKey == PhysicalKeyboardKey.escape ||
            event.physicalKey == PhysicalKeyboardKey.enter) {
          widget.exit(current: widget.images[_index]);
        }
        return KeyEventResult.handled;
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.file(
                File(widget.images[_index]),
              ),
            ),
            InfoOverlay(
              image: widget.images[_index],
              level: _overlayLevel,
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/utils/file.dart';
import 'package:foto/utils/platform_keyboard.dart';
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
    Preferences.getOverlayLevel().then(
      (value) => setState(() {
        _overlayLevel = value;
      }),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKey: (_, event) =>
          _onKey(event) ? KeyEventResult.handled : KeyEventResult.ignored,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onDoubleTap: () => _exit(false),
                child: Image.file(
                  File(widget.images[_index]),
                ),
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

  bool _onKey(RawKeyEvent event) {
    if (PlatformKeyboard.isPrevious(event)) {
      _previous();
      return true;
    } else if (PlatformKeyboard.isNext(event)) {
      _next();
      return true;
    } else if (event.isKeyPressed(LogicalKeyboardKey.keyI)) {
      _toggleLevel();
      return true;
    } else if (PlatformKeyboard.isDelete(event)) {
      _confirmDelete();
      return true;
    } else if (PlatformKeyboard.isEnter(event)) {
      _exit(false);
      return true;
    } else if (PlatformKeyboard.isEscape(event)) {
      _exit(true);
      return true;
    } else {
      return false;
    }
  }

  void _exit(bool quit) {
    widget.exit(
      quit: quit,
      current: widget.images.isEmpty ? null : widget.images[_index],
    );
  }

  void _previous() {
    setState(() {
      _index = _index == 0 ? widget.images.length - 1 : _index - 1;
    });
  }

  void _next() {
    setState(() {
      _index = _index == widget.images.length - 1 ? 0 : _index + 1;
    });
  }

  void _toggleLevel() {
    var index = _overlayLevel.index;
    index = (index + 1) % OverlayLevel.values.length;
    setState(() {
      _overlayLevel = OverlayLevel.values[index];
      Preferences.saveOverlayLevel(_overlayLevel);
    });
  }

  void _confirmDelete() {
    FileUtils.confirmDelete(context, [widget.images[_index]]).then((deleted) {
      if (deleted) {
        // remove
        widget.images.removeAt(_index);
        if (widget.images.isEmpty) {
          _exit(false);
        } else {
          if (_index == widget.images.length) {
            setState(() {
              _index = _index - 1;
            });
          } else {
            setState(() {});
          }
        }
      }
    });
  }
}

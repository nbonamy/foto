import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/utils/file.dart';
import 'package:foto/utils/platform_keyboard.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/viewer/overlay.dart';
import 'package:photo_view/photo_view.dart';

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

class _ImageViewerState extends State<ImageViewer>
    with TickerProviderStateMixin {
  late int _index;
  double? _fitScale;
  late PhotoViewController _controller;
  late AnimationController _scaleAnimationController;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    _resetState();
    _index = max(0, widget.start);
    _scaleAnimationController = AnimationController(vsync: this)
      ..addListener(() {
        _controller.scale = _scaleAnimation!.value;
      });
    super.initState();
  }

  void _resetState() {
    _fitScale = null;
    _initController();
  }

  void _initController() {
    _controller = PhotoViewController();
    _controller.outputStateStream.listen((event) {
      if (event.scale != null && _fitScale == null) {
        setState(() {
          _fitScale = event.scale;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKey: (_, event) => _onKey(event),
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    if (pointerSignal.scrollDelta.dy > 0) {
                      _zoom(false, animate: false);
                    } else if (pointerSignal.scrollDelta.dy < 0) {
                      _zoom(true, animate: false);
                    }
                  }
                },
                child: GestureDetector(
                  onDoubleTap: () => _exit(false),
                  child: PhotoView(
                    key: Key(widget.images[_index]),
                    controller: _controller,
                    imageProvider: FileImage(
                      File(widget.images[_index]),
                    ),
                    initialScale: _fitScale ?? PhotoViewComputedScale.contained,
                    maxScale: _fitScale == null ? 1.0 : null,
                    //minScale: PhotoViewComputedScale.contained * 0.8,
                    //maxScale: PhotoViewComputedScale.contained * 5,
                  ),
                ),
              ),
            ),
            StreamBuilder<PhotoViewControllerValue>(
              stream: _controller.outputStateStream,
              builder: (context, snapshot) => InfoOverlay(
                image: widget.images[_index],
                scale: snapshot.hasError ? null : snapshot.data?.scale,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setScale(double scale, {bool animate = true}) {
    if (animate) {
      _scaleAnimation = Tween<double>(
        begin: _controller.scale,
        end: scale,
      ).animate(_scaleAnimationController);
      _scaleAnimationController
        ..value = 0.0
        ..fling(velocity: 25.0);
    } else {
      _controller.scale = scale;
    }
  }

  void _zoom(bool zoomIn, {bool animate = true}) {
    var scale = _controller.scale;
    if (scale != null) {
      if (zoomIn) {
        _setScale(min(20.0, scale * 1.1), animate: animate);
      } else {
        _setScale(max(0.1, scale / 1.1), animate: animate);
      }
    }
  }

  void _nozoom() {
    _setScale(1.0);
  }

  void _fit() {
    if (_fitScale != null) {
      _setScale(_fitScale!);
    }
  }

  KeyEventResult _onKey(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.minus) ||
        event.isKeyPressed(LogicalKeyboardKey.numpadSubtract)) {
      _zoom(false);
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.add) ||
        event.isKeyPressed(LogicalKeyboardKey.numpadAdd)) {
      _zoom(true);
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.equal) ||
        event.isKeyPressed(LogicalKeyboardKey.numpadEqual)) {
      _nozoom();
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.slash) ||
        event.isKeyPressed(LogicalKeyboardKey.numpadDivide)) {
      _fit();
      return KeyEventResult.handled;
    } else if (PlatformKeyboard.isPrevious(event)) {
      _previous();
      return KeyEventResult.handled;
    } else if (PlatformKeyboard.isNext(event)) {
      _next();
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.keyI)) {
      _toggleLevel();
      return KeyEventResult.handled;
    } else if (PlatformKeyboard.isDelete(event)) {
      _confirmDelete();
      return KeyEventResult.handled;
    } else if (PlatformKeyboard.isEnter(event)) {
      _exit(false);
      return KeyEventResult.handled;
    } else if (PlatformKeyboard.isEscape(event)) {
      _exit(true);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
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
      _resetState();
      _index = _index == 0 ? widget.images.length - 1 : _index - 1;
    });
  }

  void _next() {
    setState(() {
      _resetState();
      _index = _index == widget.images.length - 1 ? 0 : _index + 1;
    });
  }

  void _toggleLevel() {
    Preferences prefs = Preferences.of(context);
    var index = prefs.overlayLevel.index;
    index = (index + 1) % OverlayLevel.values.length;
    Preferences.of(context).overlayLevel = OverlayLevel.values[index];
    setState(() {});
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

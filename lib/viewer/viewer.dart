import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/model/menu_actions.dart';
import 'package:foto/utils/file.dart';
import 'package:foto/utils/image_utils.dart';
import 'package:foto/utils/platform_keyboard.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/viewer/image.dart';
import 'package:foto/viewer/overlay.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewer extends StatefulWidget {
  final List<String> images;
  final int start;
  final MenuActionStream menuActionStream;
  final Function exit;
  const ImageViewer({
    Key? key,
    required this.images,
    required this.start,
    required this.menuActionStream,
    required this.exit,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with TickerProviderStateMixin {
  late int _index;
  double? _fitScale;
  final FocusNode _focusNode = FocusNode();
  ImageFile? _imageProvider;
  late PhotoViewController _controller;
  late AnimationController _scaleAnimationController;
  Animation<double>? _scaleAnimation;
  StreamSubscription<MenuAction>? _menuSubscription;

  String get currentImage {
    return widget.images[_index];
  }

  @override
  void initState() {
    _resetState();
    _index = _cycleIndex(widget.start);
    _scaleAnimationController = AnimationController(vsync: this)
      ..addListener(() {
        _controller.scale = _scaleAnimation!.value;
      });
    _menuSubscription =
        widget.menuActionStream.listen((event) => _onMenuAction(event));
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _preload(_index - 1);
    _preload(_index + 1);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _menuSubscription?.cancel();
    super.dispose();
  }

  void _resetState({bool invalidateOnly = false}) {
    if (invalidateOnly && _imageProvider != null) {
      _imageProvider?.invalidate();
    } else {
      _imageProvider = null;
    }
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
    _imageProvider ??= ImageFile(currentImage);

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      debugLabel: 'viewer',
      //onFocusChange: (hasFocus) {
      //  debugPrint('viewer ${hasFocus ? "on" : "off"}');
      //},
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
                    key: Key(_imageProvider.hashCode.toString()),
                    controller: _controller,
                    imageProvider: _imageProvider,
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
                image: currentImage,
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

  void _onMenuAction(MenuAction action) {
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    switch (action) {
      case MenuAction.editDelete:
        _confirmDelete();
        break;
      case MenuAction.imageRotate90cw:
        _rotateImage(ImageTransformation.rotate90CW);
        break;
      case MenuAction.imageRotate90ccw:
        _rotateImage(ImageTransformation.rotate90CCW);
        break;
      case MenuAction.imageRotate180:
        _rotateImage(ImageTransformation.rotate180);
        break;
      default:
        break;
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
    } else if (event.isKeyPressed(LogicalKeyboardKey.keyA)) {
      _toggleOverlay();
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
      current: widget.images.isEmpty ? null : currentImage,
    );
  }

  int _cycleIndex(int index) {
    if (index < 0) return widget.images.length - 1;
    if (index > widget.images.length - 1) return 0;
    return index;
  }

  Future<void> _preload(int index) {
    return precacheImage(ImageFile(widget.images[_cycleIndex(index)]), context);
  }

  void _previous() {
    setState(() {
      _resetState();
      _index = _cycleIndex(_index - 1);
      _preload(_index - 1);
    });
  }

  void _next() {
    setState(() {
      _resetState();
      _index = _cycleIndex(_index + 1);
      _preload(_index + 1);
    });
  }

  void _toggleLevel() {
    Preferences prefs = Preferences.of(context);
    var index = prefs.overlayLevel.index;
    index = (index + 1) % OverlayLevel.values.length;
    Preferences.of(context).overlayLevel = OverlayLevel.values[index];
    setState(() {});
  }

  void _toggleOverlay() {
    Preferences prefs = Preferences.of(context);
    var index = prefs.overlayLevel.index;
    var last = OverlayLevel.values.length - 1;
    index = (index == last) ? 0 : last;
    Preferences.of(context).overlayLevel = OverlayLevel.values[index];
    setState(() {});
  }

  void _rotateImage(ImageTransformation transformation) async {
    bool rc = await ImageUtils.transformImage(currentImage, transformation);
    if (rc) {
      _resetState(invalidateOnly: true);
      setState(() {});
    }
  }

  void _confirmDelete() {
    FileUtils.confirmDelete(context, [currentImage]).then((deleted) {
      if (deleted !=null && deleted) {
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

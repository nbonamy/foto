import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:photo_view/photo_view.dart';
import 'package:window_manager/window_manager.dart';

import '../components/context_menu.dart' as ctxm;
import '../model/menu_actions.dart';
import '../model/preferences.dart';
import '../utils/file.dart';
import '../utils/image_utils.dart';
import '../utils/platform_keyboard.dart';
import '../utils/utils.dart';
import 'image.dart';
import 'overlay.dart';

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
    with TickerProviderStateMixin, WindowListener, MenuHandler {
  late int _index;
  double? _fitScale;
  double? _fillScale;
  final FocusNode _focusNode = FocusNode();
  ImageFile? _imageProvider;
  late PhotoViewController _controller;
  late AnimationController _scaleAnimationController;
  Animation<double>? _scaleAnimation;
  late Preferences _preferences;
  Timer? _slideshowTimer;

  String get currentImage {
    return widget.images[_index];
  }

  @override
  void initState() {
    _resetState();
    _preferences = Preferences.of(context);
    initMenuSubscription(widget.menuActionStream);
    _index = _cycleIndex(widget.start);
    _scaleAnimationController = AnimationController(vsync: this)
      ..addListener(() {
        _controller.scale = _scaleAnimation!.value;
      });
    windowManager.addListener(this);
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
    cancelMenuSubscription();
    windowManager.removeListener(this);
    _slideshowTimer?.cancel();
    super.dispose();
  }

  void _resetState({bool invalidateOnly = false}) {
    if (invalidateOnly && _imageProvider != null) {
      _imageProvider?.invalidate();
    } else {
      _imageProvider = null;
    }
    _fitScale = null;
    _fillScale = null;
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
    // update based on last data
    _imageProvider ??= ImageFile(currentImage);
    if (_fitScale != null && _fillScale == null) {
      _calcFitFillScales();
    }

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
                  child: _getContextMenu(
                    context: context,
                    child: PhotoView(
                      key: Key(_imageProvider.hashCode.toString()),
                      controller: _controller,
                      imageProvider: _imageProvider,
                      initialScale:
                          _fitScale ?? PhotoViewComputedScale.contained,
                      maxScale: _fitScale == null ? 1.0 : null,
                      //minScale: PhotoViewComputedScale.contained * 0.8,
                      //maxScale: PhotoViewComputedScale.contained * 5,
                    ),
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

  Widget _getContextMenu(
      {required BuildContext context, required Widget child}) {
    return ctxm.ContextMenu(
      menu: ctxm.Menu(
        items: [
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: _isSlideshowing()
                ? AppLocalizations.of(context)!.viewerStopSlideShow
                : AppLocalizations.of(context)!.viewerStartSlideShow,
            shortcutKey: 's',
            shortcutModifiers: ctxm.ShortcutModifier(command: true),
            onClick: (_) => _toggleSlideshow(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.viewerFitScreen,
            shortcutKey: '/',
            onClick: (_) => _fit(),
          ),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.viewerFillScreen,
            shortcutKey: '.',
            onClick: (_) => _fill(),
          ),
          ctxm.MenuItem.submenu(
            label: AppLocalizations.of(context)!.viewerZoom,
            submenu: ctxm.Menu(
              items: [
                ctxm.MenuItem(
                  label: AppLocalizations.of(context)!.viewerZoomIn,
                  shortcutKey: '+',
                  onClick: (_) => _zoom(true),
                ),
                ctxm.MenuItem(
                  label: AppLocalizations.of(context)!.viewerZoomOut,
                  shortcutKey: '-',
                  onClick: (_) => _zoom(false),
                ),
                ctxm.MenuItem.separator(),
                ctxm.MenuItem(
                  label: AppLocalizations.of(context)!.viewerZoom100,
                  shortcutKey: '=',
                  onClick: (_) => _nozoom(),
                ),
              ],
            ),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.viewerFirstImage,
            onClick: (_) => _first(),
          ),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.viewerPreviousImage,
            shortcutKey: '◀',
            onClick: (_) => _previous(),
          ),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.viewerNextImage,
            shortcutKey: '▶',
            onClick: (_) => _next(),
          ),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.viewerLastImage,
            onClick: (_) => _last(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.viewerToggleInfo,
            shortcutKey: 'i',
            onClick: (_) => _toggleLevel(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem.submenu(
            label: AppLocalizations.of(context)!.menuImageTransform,
            submenu: ctxm.Menu(
              items: [
                ctxm.MenuItem(
                  label: AppLocalizations.of(context)!.menuImageRotate90CW,
                  shortcutKey: '▶',
                  shortcutModifiers: ctxm.ShortcutModifier(command: true),
                  onClick: (_) => _rotateImage(ImageTransformation.rotate90CW),
                ),
                ctxm.MenuItem(
                  label: AppLocalizations.of(context)!.menuImageRotate90CCW,
                  shortcutKey: '◀',
                  shortcutModifiers: ctxm.ShortcutModifier(command: true),
                  onClick: (_) => _rotateImage(ImageTransformation.rotate90CCW),
                ),
                ctxm.MenuItem.separator(),
                ctxm.MenuItem(
                  label: AppLocalizations.of(context)!.menuImageRotate180,
                  shortcutKey: '▼',
                  shortcutModifiers: ctxm.ShortcutModifier(command: true),
                  onClick: (_) => _rotateImage(ImageTransformation.rotate180),
                ),
              ],
            ),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.menuEditDelete,
            shortcutKey: '⌫',
            shortcutModifiers: ctxm.ShortcutModifier(command: true),
            onClick: (_) => _confirmDelete(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: AppLocalizations.of(context)!.viewerClose,
            shortcutKey: '↩',
            onClick: (_) => _exit(true),
          ),
        ],
      ),
      child: child,
    );
  }

  void _setScale(double scale, {bool animate = true}) {
    if (animate && _controller.scale != null) {
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

  void _fill() {
    if (_fillScale != null) {
      _setScale(_fillScale!);
    }
  }

  bool _isSlideshowing() {
    return (_slideshowTimer != null);
  }

  void _startSlideshow() {
    _stopSlideshow();
    _slideshowTimer = Timer.periodic(
      Duration(milliseconds: _preferences.slideshowDurationMs),
      (_) => _next(),
    );
    setState(() {});
  }

  void _stopSlideshow() {
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    setState(() {});
  }

  void _toggleSlideshow() {
    if (_isSlideshowing()) {
      _stopSlideshow();
    } else {
      _startSlideshow();
    }
  }

  @override
  void onMenuAction(MenuAction action) {
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
    } else if (event.isKeyPressed(LogicalKeyboardKey.period) ||
        event.isKeyPressed(LogicalKeyboardKey.numpadComma)) {
      _fill();
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
    } else if (event.isKeyPressed(LogicalKeyboardKey.keyA) &&
        PlatformKeyboard.commandModifierPressed(event)) {
      _toggleSlideshow();
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

  void _first() {
    setState(() {
      _resetState();
      _index = 0;
      _preload(_index + 1);
    });
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

  void _last() {
    setState(() {
      _resetState();
      _index = widget.images.length - 1;
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
    FileUtils.confirmDelete(
      context,
      [currentImage],
      barrierColor: Colors.black.withOpacity(0.6),
    ).then((deleted) {
      if (deleted != null && deleted) {
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

  Future<void> _calcFitFillScales() async {
    Rect screenBounds = await windowManager.getBounds();
    SizeInt imageSize = Utils.imageSize(currentImage);
    _fitScale = Utils.scaleForContained(screenBounds.size, imageSize.toSize());
    _fillScale = Utils.scaleForCovering(screenBounds.size, imageSize.toSize());
  }

  @override
  void onWindowResized() {
    double? currentScale = _controller.scale;
    bool isFitted = currentScale != null && currentScale == _fitScale;
    bool isFilled = currentScale != null && currentScale == _fillScale;
    _calcFitFillScales().then((_) {
      setState(() {
        if (currentScale == null) {
        } else if (isFitted) {
          _fit();
        } else if (isFilled) {
          _fill();
        }
      });
    });
  }
}

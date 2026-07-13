import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:photo_view/photo_view.dart';
import 'package:window_manager/window_manager.dart';

import '../components/context_menu.dart' as ctxm;
import '../model/menu_actions.dart';
import '../model/preferences.dart';
import '../utils/file_utils.dart';
import '../utils/image_utils.dart';
import '../utils/platform_keyboard.dart';
import '../utils/utils.dart';
import 'image.dart';
import 'overlay.dart';

class ImageViewer extends StatefulWidget {
  final List<String> images;
  final int start;
  final MenuActionStream menuActionStream;
  final void Function({String? current, bool? quit}) exit;
  const ImageViewer({
    super.key,
    required this.images,
    required this.start,
    required this.menuActionStream,
    required this.exit,
  });

  @override
  State<StatefulWidget> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with TickerProviderStateMixin, WindowListener, MenuHandler {
  late final List<String> _images;
  late int _index;
  double? _fitScale;
  double? _fillScale;
  bool _calculatingScales = false;
  final FocusNode _focusNode = FocusNode();
  ImageFile? _imageProvider;
  late PhotoViewController _controller;
  StreamSubscription<PhotoViewControllerValue>? _controllerSubscription;
  late AnimationController _scaleAnimationController;
  Animation<double>? _scaleAnimation;
  PhotoViewController? _scaleAnimationTarget;
  late Preferences _preferences;
  Timer? _slideshowTimer;
  final Set<String> _rotatingImages = <String>{};
  bool _deletePending = false;
  bool _isExiting = false;

  bool get _hasImages => _images.isNotEmpty;

  String get currentImage => _images[_index];

  @override
  void initState() {
    super.initState();
    _images = List<String>.of(widget.images);
    _index = _hasImages ? widget.start.clamp(0, _images.length - 1) : 0;
    _preferences = Preferences.of(context);
    _scaleAnimationController = AnimationController(vsync: this)
      ..addListener(() {
        final Animation<double>? animation = _scaleAnimation;
        final PhotoViewController? target = _scaleAnimationTarget;
        if (animation != null && target != null) {
          target.scale = animation.value;
        }
      });
    _initController();
    initMenuSubscription(widget.menuActionStream);
    windowManager.addListener(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_images.length > 1) {
      _preload(_index - 1);
      _preload(_index + 1);
    }
  }

  @override
  void dispose() {
    cancelMenuSubscription();
    windowManager.removeListener(this);
    _slideshowTimer?.cancel();
    _scaleAnimationController.dispose();
    _controllerSubscription?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetState() {
    _scaleAnimationController.stop();
    _scaleAnimation = null;
    _scaleAnimationTarget = null;
    _imageProvider = null;
    _fitScale = null;
    _fillScale = null;
    _calculatingScales = false;
    _initController();
  }

  void _initController() {
    final PhotoViewController? oldController =
        _controllerSubscription == null ? null : _controller;
    final StreamSubscription<PhotoViewControllerValue>? oldSubscription =
        _controllerSubscription;
    final PhotoViewController controller = PhotoViewController();
    _controller = controller;
    _controllerSubscription = controller.outputStateStream.listen((event) {
      if (mounted &&
          identical(controller, _controller) &&
          event.scale != null &&
          _fitScale == null) {
        setState(() => _fitScale = event.scale);
      }
    });

    if (oldController != null) {
      oldSubscription?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasImages) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _exit(false));
      return const ColoredBox(color: Colors.black);
    }

    // update based on last data
    _imageProvider ??= ImageFile(currentImage);
    if (_fitScale != null && _fillScale == null && !_calculatingScales) {
      _calcFitFillScales();
    }

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      debugLabel: 'viewer',
      //onFocusChange: (hasFocus) {
      //  debugPrint('viewer ${hasFocus ? "on" : "off"}');
      //},
      onKeyEvent: (_, event) => _onKey(event),
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
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 64,
                        ),
                      ),
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
                key: ValueKey(_imageProvider.hashCode),
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
    AppLocalizations t = AppLocalizations.of(context)!;
    return ctxm.ContextMenu(
      menu: ctxm.Menu(
        items: [
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: _isSlideshowing()
                ? t.viewerStopSlideShow
                : t.viewerStartSlideShow,
            disabled: _images.length < 2,
            shortcutKey: 's',
            shortcutModifiers: ctxm.ShortcutModifier(command: true),
            onClick: (_) => _toggleSlideshow(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: t.viewerFitScreen,
            shortcutKey: '/',
            onClick: (_) => _fit(),
          ),
          ctxm.MenuItem(
            label: t.viewerFillScreen,
            shortcutKey: '.',
            onClick: (_) => _fill(),
          ),
          ctxm.MenuItem.submenu(
            label: t.viewerZoom,
            submenu: ctxm.Menu(
              items: [
                ctxm.MenuItem(
                  label: t.viewerZoomIn,
                  shortcutKey: '+',
                  onClick: (_) => _zoom(true),
                ),
                ctxm.MenuItem(
                  label: t.viewerZoomOut,
                  shortcutKey: '-',
                  onClick: (_) => _zoom(false),
                ),
                ctxm.MenuItem.separator(),
                ctxm.MenuItem(
                  label: t.viewerZoom100,
                  shortcutKey: '=',
                  onClick: (_) => _noZoom(),
                ),
              ],
            ),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: t.viewerFirstImage,
            disabled: _index == 0,
            onClick: (_) => _first(),
          ),
          ctxm.MenuItem(
            label: t.viewerPreviousImage,
            disabled: _images.length < 2,
            shortcutKey: '◀',
            onClick: (_) => _previous(),
          ),
          ctxm.MenuItem(
            label: t.viewerNextImage,
            disabled: _images.length < 2,
            shortcutKey: '▶',
            onClick: (_) => _next(),
          ),
          ctxm.MenuItem(
            label: t.viewerLastImage,
            disabled: _index == _images.length - 1,
            onClick: (_) => _last(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: t.viewerToggleInfo,
            shortcutKey: 'i',
            onClick: (_) => _toggleLevel(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem.submenu(
            label: t.menuImageTransform,
            submenu: ctxm.Menu(
              items: [
                ctxm.MenuItem(
                  label: t.menuImageRotate90CW,
                  shortcutKey: '▶',
                  shortcutModifiers: ctxm.ShortcutModifier(command: true),
                  onClick: (_) => _rotateImage(ImageTransformation.rotate90CW),
                ),
                ctxm.MenuItem(
                  label: t.menuImageRotate90CCW,
                  shortcutKey: '◀',
                  shortcutModifiers: ctxm.ShortcutModifier(command: true),
                  onClick: (_) => _rotateImage(ImageTransformation.rotate90CCW),
                ),
                ctxm.MenuItem.separator(),
                ctxm.MenuItem(
                  label: t.menuImageRotate180,
                  shortcutKey: '▼',
                  shortcutModifiers: ctxm.ShortcutModifier(command: true),
                  onClick: (_) => _rotateImage(ImageTransformation.rotate180),
                ),
              ],
            ),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: t.menuEditDelete,
            shortcutKey: '⌫',
            shortcutModifiers: ctxm.ShortcutModifier(command: true),
            onClick: (_) => _confirmDelete(),
          ),
          ctxm.MenuItem.separator(),
          ctxm.MenuItem(
            label: t.viewerClose,
            shortcutKey: '↩',
            onClick: (_) => _exit(false),
          ),
        ],
      ),
      child: child,
    );
  }

  void _setScale(double scale, {bool animate = true}) {
    if (animate && _controller.scale != null) {
      _scaleAnimationController.stop();
      _scaleAnimationTarget = _controller;
      _scaleAnimation = Tween<double>(
        begin: _controller.scale,
        end: scale,
      ).animate(_scaleAnimationController);
      _scaleAnimationController
        ..value = 0.0
        ..fling(velocity: 25.0);
    } else {
      _scaleAnimationController.stop();
      _scaleAnimation = null;
      _scaleAnimationTarget = null;
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

  void _noZoom() {
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
    if (_images.length < 2) {
      return;
    }
    _stopSlideshow(notify: false);
    _slideshowTimer = Timer.periodic(
      Duration(milliseconds: _preferences.slideshowDurationMs),
      (_) {
        if (!mounted || _images.length < 2) {
          _stopSlideshow();
        } else {
          _next();
        }
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _stopSlideshow({bool notify = true}) {
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    if (notify && mounted) {
      setState(() {});
    }
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

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final LogicalKeyboardKey key = event.logicalKey;
    final bool commandPressed = PlatformKeyboard.metaIsCommandModifier()
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;

    if (key == LogicalKeyboardKey.keyS && commandPressed) {
      if (event is KeyDownEvent) {
        _toggleSlideshow();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _zoom(false);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      _zoom(true);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.numpadEqual) {
      _noZoom();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.slash ||
        key == LogicalKeyboardKey.numpadDivide) {
      _fit();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadComma) {
      _fill();
      return KeyEventResult.handled;
    } else if (!commandPressed &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.bracketLeft)) {
      _previous();
      return KeyEventResult.handled;
    } else if (!commandPressed &&
        (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.bracketRight)) {
      _next();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyI && !commandPressed) {
      _toggleLevel();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyA && !commandPressed) {
      _toggleOverlay();
      return KeyEventResult.handled;
    } else if (event.physicalKey == PhysicalKeyboardKey.enter ||
        event.physicalKey == PhysicalKeyboardKey.numpadEnter) {
      _exit(false);
      return KeyEventResult.handled;
    } else if (event.physicalKey == PhysicalKeyboardKey.escape) {
      _exit(true);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
  }

  void _exit(bool quit) {
    if (_isExiting) {
      return;
    }
    _isExiting = true;
    _stopSlideshow(notify: false);
    widget.exit(
      quit: quit,
      current: _hasImages ? currentImage : null,
    );
  }

  int _cycleIndex(int index) {
    if (!_hasImages) return 0;
    if (index < 0) return _images.length - 1;
    if (index > _images.length - 1) return 0;
    return index;
  }

  Future<void> _preload(int index) async {
    if (!_hasImages || !mounted) {
      return;
    }
    final String image = _images[_cycleIndex(index)];
    if (!File(image).existsSync()) {
      return;
    }
    try {
      await precacheImage(ImageFile(image), context);
    } catch (_) {
      // Preloading is opportunistic. The active image still has an error UI.
    }
  }

  void _first() {
    if (!_hasImages || _index == 0) {
      return;
    }
    setState(() {
      _resetState();
      _index = 0;
      _preload(_index + 1);
    });
  }

  void _previous() {
    if (_images.length < 2) {
      return;
    }
    setState(() {
      _resetState();
      _index = _cycleIndex(_index - 1);
      _preload(_index - 1);
    });
  }

  void _next() {
    if (_images.length < 2) {
      return;
    }
    setState(() {
      _resetState();
      _index = _cycleIndex(_index + 1);
      _preload(_index + 1);
    });
  }

  void _last() {
    if (!_hasImages || _index == _images.length - 1) {
      return;
    }
    setState(() {
      _resetState();
      _index = _images.length - 1;
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

  Future<void> _rotateImage(ImageTransformation transformation) async {
    if (!_hasImages) {
      return;
    }
    final String image = currentImage;
    if (!_rotatingImages.add(image)) {
      return;
    }

    try {
      final bool transformed =
          await ImageUtils.transformImage(image, transformation);
      if (!transformed) {
        return;
      }

      ImageFile.invalidatePath(image);
      if (mounted && _hasImages && currentImage == image) {
        setState(_resetState);
      }
    } catch (_) {
      // Native transforms can fail if the file changed during the operation.
    } finally {
      _rotatingImages.remove(image);
    }
  }

  Future<void> _confirmDelete() async {
    if (!_hasImages || _deletePending) {
      return;
    }
    _deletePending = true;
    _stopSlideshow();
    final String image = currentImage;

    final bool deleted = await FileUtils.confirmDelete(
      context,
      [image],
      barrierColor: Colors.black.withValues(alpha: 0.6),
    );
    _deletePending = false;
    if (!mounted || !deleted) {
      return;
    }

    final int deletedIndex = _images.indexOf(image);
    if (deletedIndex == -1) {
      return;
    }
    _images.removeAt(deletedIndex);
    ImageFile.invalidatePath(image);
    if (_images.isEmpty) {
      _exit(false);
      return;
    }

    setState(() {
      if (_index > deletedIndex) {
        _index -= 1;
      } else if (_index >= _images.length) {
        _index = _images.length - 1;
      }
      _resetState();
    });
  }

  Future<void> _calcFitFillScales() async {
    if (!_hasImages || _calculatingScales) {
      return;
    }
    _calculatingScales = true;
    final String image = currentImage;
    try {
      final Rect screenBounds = await windowManager.getBounds();
      final SizeInt imageSize = Utils.imageSize(image);
      if (!mounted || !_hasImages || currentImage != image) {
        return;
      }
      final double fit =
          Utils.scaleForContained(screenBounds.size, imageSize.toSize());
      final double fill =
          Utils.scaleForCovering(screenBounds.size, imageSize.toSize());
      setState(() {
        _fitScale = fit;
        _fillScale = fill;
      });
    } catch (_) {
      // The file or native window may disappear while async work is pending.
    } finally {
      if (mounted && _hasImages && currentImage == image) {
        _calculatingScales = false;
      }
    }
  }

  @override
  void onWindowResized() {
    if (!_hasImages) {
      return;
    }
    double? currentScale = _controller.scale;
    bool isFitted = currentScale != null && currentScale == _fitScale;
    bool isFilled = currentScale != null && currentScale == _fillScale;
    _calcFitFillScales().then((_) {
      if (!mounted || currentScale == null) {
        return;
      }
      if (isFitted) {
        _fit();
      } else if (isFilled) {
        _fill();
      }
    });
  }
}

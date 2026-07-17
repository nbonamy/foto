import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';

import '../components/theme.dart';
import '../components/toolbar.dart';
import '../viewer/image.dart';
import 'compare_sync_controller.dart';

class CompareView extends StatefulWidget {
  const CompareView({
    super.key,
    required this.images,
    required this.close,
  }) : assert(images.length >= 2 && images.length <= 4);

  final List<String> images;
  final VoidCallback close;

  @override
  State<CompareView> createState() => _CompareViewState();
}

class _CompareViewState extends State<CompareView> {
  final CompareSyncController _syncController = CompareSyncController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'photo comparison');
  int _activePane = 0;

  @override
  void initState() {
    super.initState();
    _syncController.addListener(_syncChanged);
  }

  @override
  void dispose() {
    _syncController.removeListener(_syncChanged);
    _syncController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final t = AppLocalizations.of(context)!;
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (_, event) => _handleKey(event),
      child: ColoredBox(
        color: palette.canvas,
        child: Column(
          children: [
            FotoToolbar(
              title:
                  '${t.comparePhotos} · ${p.basename(widget.images[_activePane])}',
              leading: FotoToolbarButton(
                icon: CupertinoIcons.xmark,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: widget.close,
              ),
              actions: [
                FotoToolbarButton(
                  key: const ValueKey('compare-sync'),
                  icon: Icons.link_rounded,
                  tooltip: t.compareSyncZoom,
                  selected: _syncController.synchronized,
                  onPressed: _syncController.toggleSynchronized,
                ),
                FotoToolbarButton(
                  key: const ValueKey('compare-fit'),
                  icon: Icons.fit_screen_rounded,
                  tooltip: t.viewerFitScreen,
                  onPressed: _syncController.fitAll,
                ),
                FotoToolbarButton(
                  key: const ValueKey('compare-actual-pixels'),
                  icon: Icons.filter_1_rounded,
                  tooltip: t.viewerZoom100,
                  onPressed: () =>
                      _syncController.showActualPixels(sourcePane: _activePane),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _buildLayout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayout() {
    final panes = List.generate(widget.images.length, _buildPane);
    return switch (panes.length) {
      2 => Row(
          key: const ValueKey('compare-layout-2'),
          children: [
            Expanded(child: panes[0]),
            const SizedBox(width: 8),
            Expanded(child: panes[1]),
          ],
        ),
      3 => Column(
          key: const ValueKey('compare-layout-3'),
          children: [
            Expanded(child: panes[0]),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: panes[1]),
                  const SizedBox(width: 8),
                  Expanded(child: panes[2]),
                ],
              ),
            ),
          ],
        ),
      4 => Column(
          key: const ValueKey('compare-layout-4'),
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: panes[0]),
                  const SizedBox(width: 8),
                  Expanded(child: panes[1]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: panes[2]),
                  const SizedBox(width: 8),
                  Expanded(child: panes[3]),
                ],
              ),
            ),
          ],
        ),
      _ => throw StateError('Compare requires two to four photos.'),
    };
  }

  Widget _buildPane(int index) {
    final palette = FotoPalette.of(context);
    final active = index == _activePane;
    return Tooltip(
      message: p.basename(widget.images[index]),
      child: AnimatedContainer(
        key: ValueKey('compare-pane-$index'),
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(
            color: active ? palette.selectionRing : palette.divider,
            width: active ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(active ? 3 : 1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ComparePane(
                id: index,
                path: widget.images[index],
                syncController: _syncController,
                onActivated: () {
                  _focusNode.requestFocus();
                  if (_activePane != index) setState(() => _activePane = index);
                },
              ),
              Positioned(
                left: 10,
                top: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: active
                        ? palette.selectionRing
                        : const Color(0xB8000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      widget.close();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      _syncController.toggleSynchronized();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.slash) {
      _syncController.fitAll();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.equal) {
      _syncController.showActualPixels(sourcePane: _activePane);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _ComparePane extends StatefulWidget {
  const _ComparePane({
    required this.id,
    required this.path,
    required this.syncController,
    required this.onActivated,
  });

  final int id;
  final String path;
  final CompareSyncController syncController;
  final VoidCallback onActivated;

  @override
  State<_ComparePane> createState() => _ComparePaneState();
}

class _ComparePaneState extends State<_ComparePane> {
  late final PhotoViewController _photoController;
  StreamSubscription<PhotoViewControllerValue>? _subscription;
  Size _viewportSize = Size.zero;
  double? _fitScale;
  bool _applyingSharedTransform = false;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _photoController = PhotoViewController();
    _subscription = _photoController.outputStateStream.listen(_photoChanged);
  }

  @override
  void dispose() {
    widget.syncController.unregisterPane(widget.id);
    _subscription?.cancel();
    _photoController.dispose();
    super.dispose();
  }

  void _photoChanged(PhotoViewControllerValue value) {
    final scale = value.scale;
    if (scale == null || _viewportSize.isEmpty) return;
    if (_fitScale == null) {
      _fitScale = scale;
      widget.syncController.registerPane(
        id: widget.id,
        fitScale: scale,
        viewportSize: _viewportSize,
        apply: _applySharedTransform,
      );
      return;
    }
    if (_applyingSharedTransform || !_userInteracting) return;
    widget.syncController.updateFromPane(
      id: widget.id,
      scale: scale,
      position: value.position,
    );
  }

  void _applySharedTransform(ComparePaneTransform transform) {
    _applyingSharedTransform = true;
    _photoController.updateMultiple(
      scale: transform.scale,
      position: transform.position,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyingSharedTransform = false;
    });
  }

  void _beginInteraction() {
    _userInteracting = true;
    widget.onActivated();
  }

  void _endInteraction() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _userInteracting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        if (viewport != _viewportSize && !viewport.isEmpty) {
          _viewportSize = viewport;
          widget.syncController.updatePaneMetrics(widget.id, viewport);
        }
        return Listener(
          onPointerDown: (_) => _beginInteraction(),
          onPointerUp: (_) => _endInteraction(),
          onPointerCancel: (_) => _endInteraction(),
          onPointerSignal: (signal) {
            if (signal is! PointerScrollEvent) return;
            _beginInteraction();
            final scale = _photoController.scale;
            if (scale == null) {
              _endInteraction();
              return;
            }
            final factor = signal.scrollDelta.dy < 0 ? 1.08 : 1 / 1.08;
            _photoController.scale = max(0.05, min(20, scale * factor));
            _endInteraction();
          },
          child: PhotoView(
            key: ValueKey('compare-image-${widget.id}'),
            controller: _photoController,
            imageProvider: ImageFile(widget.path),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: 20.0,
            filterQuality: FilterQuality.high,
            enablePanAlways: true,
            onTapDown: (_, __, ___) => widget.onActivated(),
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 54,
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../viewer/image.dart';

@immutable
class GalleryLoupeTarget {
  const GalleryLoupeTarget({
    required this.path,
    required this.preview,
    required this.normalizedPosition,
    required this.surfacePosition,
  });

  final String path;
  final ImageProvider preview;
  final Offset normalizedPosition;
  final Offset surfacePosition;
}

class GalleryLoupeController extends ValueNotifier<GalleryLoupeTarget?> {
  GalleryLoupeController() : super(null);

  GalleryLoupeTarget? _hovered;
  bool _held = false;

  bool get isHeld => _held;

  void hover(GalleryLoupeTarget target) {
    _hovered = target;
    if (_held) value = target;
  }

  void leave(String path) {
    if (_hovered?.path != path) return;
    _hovered = null;
    value = null;
  }

  void setHeld(bool held) {
    if (_held == held) return;
    _held = held;
    value = held ? _hovered : null;
  }
}

class LoupeGeometry {
  const LoupeGeometry._();

  static Offset normalizedSourcePosition({
    required Offset localPosition,
    required Size tileSize,
    required double imageAspectRatio,
  }) {
    if (tileSize.isEmpty ||
        !imageAspectRatio.isFinite ||
        imageAspectRatio <= 0) {
      return const Offset(0.5, 0.5);
    }

    final sourceSize = Size(imageAspectRatio, 1);
    final fitted = applyBoxFit(BoxFit.cover, sourceSize, tileSize);
    final sourceRect = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & sourceSize,
    );
    final destinationRect = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & tileSize,
    );
    final x =
        ((localPosition.dx - destinationRect.left) / destinationRect.width)
            .clamp(0.0, 1.0);
    final y =
        ((localPosition.dy - destinationRect.top) / destinationRect.height)
            .clamp(0.0, 1.0);

    return Offset(
      (sourceRect.left + sourceRect.width * x) / sourceSize.width,
      (sourceRect.top + sourceRect.height * y) / sourceSize.height,
    );
  }

  static Offset overlayOrigin({
    required Offset pointer,
    required Size surfaceSize,
    required double loupeSize,
    double gap = 22,
    double margin = 12,
  }) {
    var left = pointer.dx + gap;
    var top = pointer.dy + gap;
    if (left + loupeSize + margin > surfaceSize.width) {
      left = pointer.dx - gap - loupeSize;
    }
    if (top + loupeSize + margin > surfaceSize.height) {
      top = pointer.dy - gap - loupeSize;
    }
    final maxLeft = (surfaceSize.width - loupeSize - margin).clamp(
      margin,
      double.infinity,
    );
    final maxTop = (surfaceSize.height - loupeSize - margin).clamp(
      margin,
      double.infinity,
    );
    return Offset(
      left.clamp(margin, maxLeft),
      top.clamp(margin, maxTop),
    );
  }
}

class GalleryLoupeOverlay extends StatelessWidget {
  const GalleryLoupeOverlay({
    super.key,
    required this.target,
    this.loupeSize = 280,
  });

  final GalleryLoupeTarget target;
  final double loupeSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final surfaceSize = constraints.biggest;
        final origin = LoupeGeometry.overlayOrigin(
          pointer: target.surfacePosition,
          surfaceSize: surfaceSize,
          loupeSize: loupeSize,
        );
        return Stack(
          children: [
            Positioned(
              left: origin.dx,
              top: origin.dy,
              width: loupeSize,
              height: loupeSize,
              child: _PhotoLoupe(target: target),
            ),
          ],
        );
      },
    );
  }
}

class _PhotoLoupe extends StatefulWidget {
  const _PhotoLoupe({required this.target});

  final GalleryLoupeTarget target;

  @override
  State<_PhotoLoupe> createState() => _PhotoLoupeState();
}

class _PhotoLoupeState extends State<_PhotoLoupe> {
  ImageFile? _fullResolution;
  double? _devicePixelRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (_fullResolution == null || _devicePixelRatio != ratio) {
      _replaceProvider(ratio);
    }
  }

  @override
  void didUpdateWidget(covariant _PhotoLoupe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.path != widget.target.path) {
      _replaceProvider(_devicePixelRatio ?? 1);
    }
  }

  @override
  void dispose() {
    final provider = _fullResolution;
    if (provider != null) unawaited(provider.evict());
    super.dispose();
  }

  void _replaceProvider(double devicePixelRatio) {
    final previous = _fullResolution;
    _devicePixelRatio = devicePixelRatio;
    _fullResolution = ImageFile(
      widget.target.path,
      scale: devicePixelRatio,
    );
    if (previous != null) unawaited(previous.evict());
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final alignment = Alignment(
      widget.target.normalizedPosition.dx * 2 - 1,
      widget.target.normalizedPosition.dy * 2 - 1,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: widget.target.preview,
              fit: BoxFit.none,
              alignment: alignment,
              filterQuality: FilterQuality.medium,
            ),
            if (_fullResolution case final fullResolution?)
              Image(
                key: ValueKey('loupe-full-${widget.target.path}'),
                image: fullResolution,
                fit: BoxFit.none,
                alignment: alignment,
                filterQuality: FilterQuality.none,
                frameBuilder: (context, child, frame, synchronous) {
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Positioned(
              left: 12,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB8000000),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '100%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

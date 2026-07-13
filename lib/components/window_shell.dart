import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'theme.dart';

class FotoWindowShell extends StatelessWidget {
  const FotoWindowShell({
    super.key,
    required this.sidebar,
    required this.child,
    required this.showSidebar,
    this.sidebarWidth = 244,
  });

  static const double compactBreakpoint = 640;

  final Widget sidebar;
  final Widget child;
  final bool showSidebar;
  final double sidebarWidth;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return ColoredBox(
      color: palette.canvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidebarVisible =
              showSidebar && constraints.maxWidth >= compactBreakpoint;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sidebarVisible)
                SizedBox(
                  key: const ValueKey('foto-sidebar-region'),
                  width: sidebarWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.sidebarSurface,
                      border: Border(
                        right: BorderSide(color: palette.divider),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _FotoSidebarHeader(),
                        Expanded(child: sidebar),
                      ],
                    ),
                  ),
                ),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _FotoSidebarHeader extends StatelessWidget {
  const _FotoSidebarHeader();

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return SizedBox(
      height: 76,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DragToMoveArea(child: SizedBox.expand()),
          IgnorePointer(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                child: Text(
                  'foto',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.primaryText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FotoSplitView extends StatefulWidget {
  const FotoSplitView({
    super.key,
    required this.child,
    this.trailing,
    this.initialTrailingWidth = 280,
    this.minimumTrailingWidth = 220,
    this.maximumTrailingWidth = 420,
    this.overlayBreakpoint = 680,
  });

  final Widget child;
  final Widget? trailing;
  final double initialTrailingWidth;
  final double minimumTrailingWidth;
  final double maximumTrailingWidth;
  final double overlayBreakpoint;

  @override
  State<FotoSplitView> createState() => _FotoSplitViewState();
}

class _FotoSplitViewState extends State<FotoSplitView> {
  late double _trailingWidth = widget.initialTrailingWidth;

  @override
  Widget build(BuildContext context) {
    if (widget.trailing == null) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < widget.overlayBreakpoint) {
          final width = math.min(
            widget.maximumTrailingWidth,
            math.max(0.0, constraints.maxWidth - 24),
          );
          return Stack(
            children: [
              Positioned.fill(child: widget.child),
              Positioned(
                top: 8,
                right: 8,
                bottom: 8,
                width: width,
                child: _overlaySurface(context, widget.trailing!),
              ),
            ],
          );
        }

        final maximumWidth = math.min(
          widget.maximumTrailingWidth,
          constraints.maxWidth * 0.48,
        );
        final minimumWidth =
            math.min(widget.minimumTrailingWidth, maximumWidth);
        final trailingWidth = _trailingWidth.clamp(minimumWidth, maximumWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: widget.child),
            _ResizeHandle(
              onDrag: (delta) {
                setState(() {
                  _trailingWidth = (_trailingWidth - delta).clamp(
                    minimumWidth,
                    maximumWidth,
                  );
                });
              },
            ),
            SizedBox(
              key: const ValueKey('foto-trailing-pane'),
              width: trailingWidth,
              child: widget.trailing,
            ),
          ],
        );
      },
    );
  }

  Widget _overlaySurface(BuildContext context, Widget child) {
    final palette = FotoPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.chromeSurface,
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: child,
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          key: const ValueKey('foto-pane-resize-handle'),
          width: 7,
          child: Center(
            child: SizedBox(
              width: 1,
              height: double.infinity,
              child: ColoredBox(color: palette.divider),
            ),
          ),
        ),
      ),
    );
  }
}

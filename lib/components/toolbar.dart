import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'theme.dart';

class FotoToolbar extends StatelessWidget {
  const FotoToolbar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.chromeSurface,
          border: Border(
            bottom: BorderSide(color: palette.divider),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: DragToMoveArea(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: palette.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
              if (actions.isNotEmpty) _FotoToolbarGroup(children: actions),
              if (actions.isNotEmpty && trailing != null)
                const SizedBox(width: 8),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _FotoToolbarGroup extends StatelessWidget {
  const _FotoToolbarGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _FotoToolbarSegmentScope(
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _FotoToolbarSegmentScope extends InheritedWidget {
  const _FotoToolbarSegmentScope({required super.child});

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FotoToolbarSegmentScope>() !=
      null;

  @override
  bool updateShouldNotify(_FotoToolbarSegmentScope oldWidget) => false;
}

class FotoToolbarMenuButton<T> extends StatelessWidget {
  const FotoToolbarMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.itemBuilder,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    const radius = BorderRadius.all(Radius.circular(11));
    return Material(
      color: palette.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<T>(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        borderRadius: radius,
        position: PopupMenuPosition.under,
        onSelected: onSelected,
        itemBuilder: itemBuilder,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 8, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: palette.secondaryText),
                const SizedBox(width: 7),
                Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: palette.primaryText,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: palette.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FotoToolbarButton extends StatelessWidget {
  const FotoToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final segmented = _FotoToolbarSegmentScope.contains(context);
    return IconButton(
      icon: Icon(icon, size: 17),
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: selected,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.square(34)),
        maximumSize: const WidgetStatePropertyAll(Size.square(34)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.secondaryText.withValues(alpha: 0.45);
          }
          return selected ? palette.accent : palette.secondaryText;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (selected) return palette.selectionFill;
          if (states.contains(WidgetState.pressed)) return palette.pressed;
          if (states.contains(WidgetState.hovered)) return palette.hover;
          return Colors.transparent;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius:
                segmented ? BorderRadius.zero : BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

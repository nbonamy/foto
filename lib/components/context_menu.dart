import 'package:contextual_menu/contextual_menu.dart' as ncm;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide MenuItem;

class Menu extends ncm.Menu {
  Menu({
    super.items,
  });
}

class MenuItem extends ncm.MenuItem {
  MenuItem.separator() : super.separator();

  MenuItem({
    super.key,
    super.type = 'normal',
    super.label,
    super.sublabel,
    super.toolTip,
    super.icon,
    super.checked,
    super.disabled = false,
    super.submenu,
    super.onClick,
  });
}

class ContextMenu extends StatefulWidget {
  final Menu menu;
  final ncm.Placement placement;
  final Function? onBeforeShowMenu;
  final Widget child;

  const ContextMenu({
    Key? key,
    required this.menu,
    this.placement = ncm.Placement.bottomRight,
    this.onBeforeShowMenu,
    required this.child,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
  bool _shouldReact = false;
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _shouldReact = event.kind == PointerDeviceKind.mouse &&
            event.buttons == kSecondaryMouseButton;
        if (_shouldReact && widget.onBeforeShowMenu != null) {
          widget.onBeforeShowMenu!();
        }
      },
      onPointerUp: (event) {
        if (!_shouldReact) return;

        _position = Offset(
          event.position.dx,
          event.position.dy,
        );

        _handleClickPopUp();
      },
      child: widget.child,
    );
  }

  void _handleClickPopUp() {
    ncm.popUpContextualMenu(
      widget.menu,
      position: _position,
      placement: widget.placement,
    );
  }
}

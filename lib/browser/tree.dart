import 'dart:io';
import 'package:flutter/material.dart';
import 'package:foto/components/context_menu.dart' as ctxm;
import 'package:foto/components/theme.dart';
import 'package:foto/model/favorites.dart';
import 'package:foto/model/history.dart';
import 'package:foto/utils/file.dart';
import 'package:foto/utils/media_utils.dart';
import 'package:foto/utils/paths.dart';
import 'package:foto/utils/utils.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class BrowserTree extends StatefulWidget {
  const BrowserTree({
    Key? key,
    required this.root,
    this.title,
    this.assetName,
    this.selectedPath,
    required this.onUpdate,
  }) : super(key: key);

  final String root;
  final String? title;
  final String? assetName;
  final String? selectedPath;
  final Function onUpdate;

  @override
  State<StatefulWidget> createState() => _BrowserTreeState();
}

class _BrowserTreeState extends State<BrowserTree> {
  TreeViewController? _treeViewController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    List<Node> nodes = getRootNode(
        widget.title, widget.root, widget.assetName, widget.selectedPath);
    _treeViewController = TreeViewController(
      children: nodes,
      selectedKey: widget.selectedPath,
    );
    super.initState();
  }

  @override
  void didUpdateWidget(covariant BrowserTree oldWidget) {
    if (widget.selectedPath != oldWidget.selectedPath) {
      _treeViewController = _treeViewController == null
          ? null
          : TreeViewController(
              children: _treeViewController!.children,
              selectedKey: widget.selectedPath,
            );
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    Widget tree = _treeViewController != null
        ? Consumer3<AppTheme, HistoryModel, FavoritesModel>(
            builder: (context, theme, history, favorites, child) {
            return Material(
              type: MaterialType.transparency,
              child: TreeView(
                controller: _treeViewController!,
                theme: _getTreeTheme(context, theme),
                allowParentSelect: true,
                shrinkWrap: true,
                nodeBuilder: (context, node) {
                  return ctxm.ContextMenu(
                    menu: _buildMenu(favorites, node),
                    child: _buildNodeLabel(
                      _treeViewController!,
                      node,
                      _getTreeTheme(context, theme),
                    ),
                  );
                },
                onNodeTap: (key) {
                  _focusNode.requestFocus();
                  updateSelectedPath(history, key);
                },
                onExpansionChanged: (key, state) {
                  _focusNode.requestFocus();
                  expandPath(key, state);
                },
              ),
            );
          })
        : Container();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      child: /*Focus(
        focusNode: _focusNode,
        debugLabel: widget.root,
        //onFocusChange: (hasFocus) {
        //  if (hasFocus) debugPrint(widget.root);
        //},
        onKey: (_, event) {
          var selectedPath = _treeViewController?.selectedKey;
          if (selectedPath == null) return KeyEventResult.ignored;
          if (PlatformKeyboard.isDelete(event)) {
            FileUtils.confirmDelete(context, [selectedPath]);
            return KeyEventResult.handled;
          } else if (PlatformKeyboard.isCopy(event)) {
            Pasteboard.writeFiles([selectedPath]);
            return KeyEventResult.handled;
          } else {
            return KeyEventResult.ignored;
          }
        },
        child: */
          tree,
      //),
    );
  }

  ctxm.Menu _buildMenu(FavoritesModel favorites, Node<dynamic> node) {
    return ctxm.Menu(
      items: [
        favorites.isFavorite(node.key)
            ? ctxm.MenuItem(
                label: AppLocalizations.of(context)!.favoritesRemove,
                onClick: (_) => favorites.remove(node.key),
              )
            : ctxm.MenuItem(
                label: AppLocalizations.of(context)!.favoritesAdd,
                onClick: (_) => favorites.add(node.key),
              ),
        ctxm.MenuItem.separator(),
        ctxm.MenuItem(
          label: AppLocalizations.of(context)!.menuEditCopy,
          onClick: (_) => Pasteboard.writeFiles([node.key]),
        ),
        ctxm.MenuItem.separator(),
        ctxm.MenuItem(
          label: AppLocalizations.of(context)!.menuEditDelete,
          onClick: (_) => FileUtils.confirmDelete(context, [node.key]),
        ),
      ],
    );
  }

  TreeViewTheme _getTreeTheme(BuildContext context, AppTheme appTheme) {
    TreeViewTheme treeViewTheme = TreeViewTheme(
      expanderTheme: ExpanderThemeData(
        type: ExpanderType.chevron,
        modifier: ExpanderModifier.none,
        position: ExpanderPosition.start,
        size: 16,
        color: MacosTheme.of(context).typography.body.color,
      ),
      labelStyle: MacosTheme.of(context).typography.body.copyWith(fontSize: 12),
      parentLabelStyle:
          MacosTheme.of(context).typography.body.copyWith(fontSize: 12),
      colorScheme: Theme.of(context)
          .colorScheme
          .copyWith(primary: const Color.fromARGB(255, 48, 105, 202)),
      iconTheme: const IconThemeData(
        size: 16,
      ),
      iconPadding: 16,
      verticalSpacing: 4,
      parentLabelOverflow: TextOverflow.ellipsis,
      labelOverflow: TextOverflow.ellipsis,
    );
    return treeViewTheme;
  }

  Widget _buildNodeIcon(
      TreeViewController controller, Node node, TreeViewTheme theme) {
    return Container(
      alignment: Alignment.center,
      width: theme.iconTheme.size! + theme.iconPadding,
      child: Image.asset(
        node.data ?? SystemPath.getFolderNamedAsset(null),
        width: theme.iconTheme.size,
      ),
    );
  }

  Widget _buildNodeLabel(
      TreeViewController controller, Node node, TreeViewTheme theme) {
    bool isSelected =
        controller.selectedKey != null && controller.selectedKey == node.key;
    final icon = _buildNodeIcon(controller, node, theme);
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: theme.verticalSpacing ?? (theme.dense ? 10 : 15),
          horizontal: node.isParent ? 0 : 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            icon,
            Expanded(
              child: Text(
                node.label,
                softWrap: node.isParent
                    ? theme.parentLabelOverflow == null
                    : theme.labelOverflow == null,
                overflow: node.isParent
                    ? theme.parentLabelOverflow
                    : theme.labelOverflow,
                style: node.isParent
                    ? theme.parentLabelStyle.copyWith(
                        fontWeight: theme.parentLabelStyle.fontWeight,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.parentLabelStyle.color,
                      )
                    : theme.labelStyle.copyWith(
                        fontWeight: theme.labelStyle.fontWeight,
                        color: isSelected ? theme.colorScheme.onPrimary : null,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void updateSelectedPath(HistoryModel historyModel, String selectedPath) {
    historyModel.push(selectedPath, true);
    widget.onUpdate(widget.root);
  }

  void expandPath(String path, bool expanded) {
    Node? node = _treeViewController!.getNode(path);
    if (node != null) {
      List<Node> nodes = [];
      if (!expanded) {
        nodes = _treeViewController!.updateNode(
          path,
          node.copyWith(
            expanded: false,
          ),
        );
      } else if (node.isParent && node.children.isEmpty) {
        nodes = _treeViewController!.updateNode(
          path,
          node.copyWith(
            expanded: true,
            children: getNodes(path, path),
            parent: false,
          ),
        );
      } else {
        nodes = _treeViewController!.updateNode(
          path,
          node.copyWith(
            expanded: true,
          ),
        );
      }
      setState(() {
        _treeViewController = _treeViewController!.copyWith(
          children: nodes,
        );
      });
    }
  }

  List<Node> getRootNode(
    String? title,
    String path,
    String? assetName,
    String? selectedPath,
  ) {
    List<Node> children = [];

    if (selectedPath != null && selectedPath.startsWith(path)) {
      children = getNodes(path, selectedPath);
    }
    return [
      Node(
        key: path,
        label: title ?? Utils.pathTitle(path) ?? '',
        expanded: selectedPath != null &&
            selectedPath != path &&
            selectedPath.startsWith(path),
        data: assetName,
        children: children,
        parent: true,
      )
    ];
  }

  List<Node> getNodes(String path, String? selectedPath) {
    // init
    List<Node> nodes = [];

    try {
      // get folders
      final dir = Directory(path);
      var folders =
          dir.listSync(recursive: false).whereType<Directory>().toList();
      folders = folders
          .where((f) => !MediaUtils.shouldExcludeFileOrDir(f.path))
          .toList();
      folders
          .sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

      for (var folder in folders) {
        List<Node> children = [];

        if (selectedPath != null && selectedPath.startsWith(folder.path)) {
          children = getNodes(folder.path, selectedPath);
        }

        nodes.add(Node(
          key: folder.path,
          label: Utils.pathTitle(folder.path) ?? '',
          data: SystemPath.getFolderNamedAsset(folder.path),
          expanded: selectedPath != null &&
              selectedPath != path &&
              selectedPath.startsWith(folder.path),
          children: children,
          parent: true,
        ));
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    // done
    return nodes;
  }
}

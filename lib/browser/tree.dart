import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../components/context_menu.dart' as ctxm;
import '../model/favorites.dart';
import '../utils/file_utils.dart';
import '../utils/media_utils.dart';
import '../utils/paths.dart';
import '../utils/utils.dart';

class BrowserTree extends StatefulWidget {
  const BrowserTree({
    super.key,
    required this.root,
    this.title,
    this.assetName,
    this.selectedPath,
    required this.onUpdate,
  });

  final String root;
  final String? title;
  final String? assetName;
  final String? selectedPath;
  final void Function(String root, String selectedPath) onUpdate;

  @override
  State<BrowserTree> createState() => _BrowserTreeState();
}

class _BrowserTreeState extends State<BrowserTree> {
  static const double _indent = 16;
  static const double _iconSize = 16;

  final FocusNode _focusNode = FocusNode();
  final Set<String> _expandedPaths = {};
  final Map<String, List<Directory>> _folderCache = {};
  final Set<String> _loadingPaths = {};
  final Map<String, StreamSubscription<FileSystemEvent>> _folderWatchers = {};
  final Map<String, Timer> _reloadDebounces = {};

  @override
  void initState() {
    super.initState();
    _expandAncestorsOfSelection();
  }

  @override
  void didUpdateWidget(covariant BrowserTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.root != oldWidget.root) {
      _cancelAllWatchers();
      _expandedPaths.clear();
      _folderCache.clear();
    }
    if (widget.root != oldWidget.root ||
        widget.selectedPath != oldWidget.selectedPath) {
      _expandAncestorsOfSelection();
      _reloadExpandedSubtree(widget.root);
    }
  }

  @override
  void dispose() {
    _cancelAllWatchers();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesModel>(
      builder: (context, favorites, child) {
        return Material(
          type: MaterialType.transparency,
          child: Focus(
            focusNode: _focusNode,
            debugLabel: widget.root,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildNode(
                favorites: favorites,
                path: widget.root,
                label: widget.title ?? Utils.pathTitle(widget.root) ?? '',
                assetName: widget.assetName,
                depth: 0,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNode({
    required FavoritesModel favorites,
    required String path,
    required String label,
    required int depth,
    String? assetName,
  }) {
    final isExpanded = _expandedPaths.contains(path);
    if (isExpanded && !_folderCache.containsKey(path)) {
      unawaited(_loadFolders(path));
    }
    final isSelected = widget.selectedPath == path;
    final colorScheme = Theme.of(context).colorScheme.copyWith(
          primary: const Color.fromARGB(255, 48, 105, 202),
        );
    final labelStyle = MacosTheme.of(context).typography.body.copyWith(
          color: isSelected ? colorScheme.onPrimary : null,
          fontSize: 12,
        );

    final row = MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _focusNode.requestFocus();
          _updateSelectedPath(path);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: EdgeInsets.only(
            left: depth * _indent,
            top: 2.5,
            bottom: 2.5,
          ),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleExpanded(path),
                child: SizedBox(
                  width: _iconSize,
                  height: _iconSize,
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: _iconSize,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : MacosTheme.of(context).typography.body.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: Image.asset(
                  assetName ?? SystemPath.getFolderNamedAsset(null),
                  width: _iconSize,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ctxm.ContextMenu(
          menu: _buildMenu(favorites, path),
          child: row,
        ),
        if (isExpanded)
          for (final folder in _folderCache[path] ?? const <Directory>[])
            _buildNode(
              favorites: favorites,
              path: folder.path,
              label: Utils.pathTitle(folder.path) ?? '',
              assetName: SystemPath.getFolderNamedAsset(folder.path),
              depth: depth + 1,
            ),
      ],
    );
  }

  ctxm.Menu _buildMenu(FavoritesModel favorites, String path) {
    final t = AppLocalizations.of(context)!;
    return ctxm.Menu(
      items: [
        favorites.isFavorite(path)
            ? ctxm.MenuItem(
                label: t.favoritesRemove,
                onClick: (_) => favorites.remove(path),
              )
            : ctxm.MenuItem(
                label: t.favoritesAdd,
                onClick: (_) => favorites.add(path),
              ),
        ctxm.MenuItem.separator(),
        ctxm.MenuItem(
          label: t.menuEditCopyItems,
          onClick: (_) => Pasteboard.writeFiles([path]),
        ),
        ctxm.MenuItem(
          label: t.menuEditPaste,
          onClick: (_) => FileUtils.tryPaste(context, path, false),
        ),
        ctxm.MenuItem(
          label: t.menuEditPasteMove,
          onClick: (_) => FileUtils.tryPaste(context, path, true),
        ),
        ctxm.MenuItem.separator(),
        ctxm.MenuItem(
          label: t.menuEditDelete,
          onClick: (_) => FileUtils.confirmDelete(context, [path]),
        ),
      ],
    );
  }

  void _updateSelectedPath(String selectedPath) {
    widget.onUpdate(widget.root, selectedPath);
  }

  void _toggleExpanded(String path) {
    _focusNode.requestFocus();
    setState(() {
      if (_expandedPaths.remove(path)) {
        _stopWatchingAtOrBelow(path);
      } else {
        _expandedPaths.add(path);
        _reloadExpandedSubtree(path);
      }
    });
  }

  void _expandAncestorsOfSelection() {
    final selectedPath = widget.selectedPath;
    if (selectedPath == null ||
        selectedPath == widget.root ||
        !MediaUtils.isPathAtOrBelow(selectedPath, widget.root)) {
      return;
    }

    var ancestor = p.dirname(selectedPath);
    while (MediaUtils.isPathAtOrBelow(ancestor, widget.root)) {
      _expandedPaths.add(ancestor);
      if (ancestor == widget.root) {
        break;
      }
      final parent = p.dirname(ancestor);
      if (parent == ancestor) {
        break;
      }
      ancestor = parent;
    }
  }

  Future<void> _loadFolders(String path, {bool force = false}) async {
    if ((!force && _folderCache.containsKey(path)) ||
        !_loadingPaths.add(path)) {
      return;
    }

    try {
      final entities = await Directory(path)
          .list(recursive: false, followLinks: false)
          .toList();
      final folders = entities
          .whereType<Directory>()
          .where((folder) => !MediaUtils.shouldExcludeFileOrDir(folder.path))
          .toList();
      folders.sort(
        (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
      );
      if (!mounted) return;
      _folderCache[path] = folders;
      if (_isEffectivelyExpanded(path)) {
        _watchFolder(path);
        setState(() {});
      }
    } catch (error) {
      debugPrint('Unable to list $path: $error');
      if (mounted) {
        setState(() {
          _folderCache[path] = const <Directory>[];
        });
      }
    } finally {
      _loadingPaths.remove(path);
    }
  }

  void _watchFolder(String path) {
    if (_folderWatchers.containsKey(path)) return;
    try {
      _folderWatchers[path] = Directory(path).watch().listen(
        (_) {
          _reloadDebounces[path]?.cancel();
          _reloadDebounces[path] = Timer(
            const Duration(milliseconds: 100),
            () => _loadFolders(path, force: true),
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Unable to watch $path: $error');
          _folderWatchers.remove(path)?.cancel();
        },
      );
    } catch (error) {
      debugPrint('Unable to watch $path: $error');
    }
  }

  void _stopWatchingAtOrBelow(String path) {
    final watchedPaths = _folderWatchers.keys
        .where((watched) => MediaUtils.isPathAtOrBelow(watched, path))
        .toList(growable: false);
    for (final watched in watchedPaths) {
      _folderWatchers.remove(watched)?.cancel();
      _reloadDebounces.remove(watched)?.cancel();
    }
  }

  void _reloadExpandedSubtree(String path) {
    final expandedPaths = _expandedPaths
        .where((expanded) =>
            MediaUtils.isPathAtOrBelow(expanded, path) &&
            _isEffectivelyExpanded(expanded))
        .toList(growable: false);
    for (final expanded in expandedPaths) {
      unawaited(_loadFolders(expanded, force: true));
    }
  }

  bool _isEffectivelyExpanded(String path) {
    if (!_expandedPaths.contains(path) ||
        !MediaUtils.isPathAtOrBelow(path, widget.root)) {
      return false;
    }

    var current = path;
    while (current != widget.root) {
      final parent = p.dirname(current);
      if (parent == current || !_expandedPaths.contains(parent)) {
        return false;
      }
      current = parent;
    }
    return true;
  }

  void _cancelAllWatchers() {
    for (final subscription in _folderWatchers.values) {
      subscription.cancel();
    }
    for (final timer in _reloadDebounces.values) {
      timer.cancel();
    }
    _folderWatchers.clear();
    _reloadDebounces.clear();
  }
}

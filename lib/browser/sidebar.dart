import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../components/context_menu.dart' as ctxm;
import '../components/theme.dart';
import '../model/favorites.dart';
import '../model/history.dart';
import '../utils/media_utils.dart';
import '../utils/paths.dart';
import '../utils/utils.dart';
import 'tree.dart';

class RootNode {
  final String? _title;
  final String _path;

  RootNode(this._title, this._path);

  String get title {
    return _title ?? Utils.pathTitle(_path) ?? '';
  }

  String get path {
    return _path;
  }
}

class BrowserSidebar extends StatefulWidget {
  final ScrollController scrollController;
  final ValueChanged<String> navigateToFolder;

  const BrowserSidebar({
    super.key,
    required this.scrollController,
    required this.navigateToFolder,
  });

  @override
  State<StatefulWidget> createState() => _SidebarState();
}

class _SidebarState extends State<BrowserSidebar> {
  String? _activeRoot;
  final FocusNode _focusNode = FocusNode(debugLabel: 'browser sidebar');
  final List<RootNode> _devices = [];
  StreamSubscription<FileSystemEvent>? _volumesSubscription;
  Timer? _deviceRefreshDebounce;

  @override
  void initState() {
    super.initState();
    _getDevices();
    _watchDevices();
  }

  @override
  void dispose() {
    _deviceRefreshDebounce?.cancel();
    _volumesSubscription?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _getDevices() {
    final devices = <RootNode>[];
    try {
      // list stuff in volumes
      for (var entity in Directory('/Volumes')
          .listSync(recursive: false, followLinks: false)) {
        try {
          var title = Utils.pathTitle(entity.path);
          if (entity is Directory) {
            devices.add(RootNode(
              title,
              entity.path,
            ));
          } else if (entity is Link) {
            devices.add(RootNode(
              title,
              entity.resolveSymbolicLinksSync(),
            ));
          }
        } catch (e) {
          debugPrint(e.toString());
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    // we need root
    if (devices.indexWhere((element) => element.path == '/') == -1) {
      devices.add(RootNode('Macintosh HD', '/'));
    }

    // now sort devices by path
    devices.sort((a, b) => a.path.compareTo(b.path));
    _devices
      ..clear()
      ..addAll(devices);
  }

  void _watchDevices() {
    try {
      _volumesSubscription = Directory('/Volumes').watch().listen((event) {
        _deviceRefreshDebounce?.cancel();
        _deviceRefreshDebounce = Timer(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(_getDevices);
        });
      }, onError: (Object error, StackTrace stackTrace) {
        debugPrint('Unable to watch mounted volumes: $error');
      });
    } catch (error) {
      debugPrint('Unable to watch mounted volumes: $error');
    }
  }

  void _initActiveRoot(BuildContext context) {
    // get data
    var history = HistoryModel.of(context);
    var favorites = FavoritesModel.of(context).get;

    // default active root
    _activeRoot = MediaUtils.deepestContainingRoot(history.top, favorites);
    _activeRoot ??= MediaUtils.deepestContainingRoot(
      history.top,
      _devices.map((device) => device.path),
    );
  }

  void _checkActiveRoot(BuildContext context) {
    _initActiveRoot(context);
  }

  @override
  Widget build(BuildContext context) {
    //
    return Consumer2<HistoryModel, FavoritesModel>(
      builder: (context, history, favorites, child) {
        // we need a root
        _checkActiveRoot(context);

        // now build
        return Focus(
          focusNode: _focusNode,
          child: CustomScrollView(
            controller: widget.scrollController,
            slivers: _buildSidebarSlivers(context, history, favorites),
          ),
        );
      },
    );
  }

  List<Widget> _buildSidebarSlivers(
    BuildContext context,
    HistoryModel historyModel,
    FavoritesModel favoritesModel,
  ) {
    final sidebarContent = <Widget>[];

    // favorites
    List<String> favorites = favoritesModel.get;
    if (favorites.isNotEmpty) {
      final favoritesList = SizedBox(
        height: favorites.length * FavoriteShortcut.rowExtent,
        child: ReorderableListView.builder(
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: favorites.length,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                final double animValue =
                    Curves.easeInOut.transform(animation.value);
                final double elevation = lerpDouble(0, 6, animValue)!;
                return Material(
                  elevation: elevation,
                  child: child,
                );
              },
              child: Container(
                color: Theme.of(context).highlightColor,
                child: child,
              ),
            );
          },
          onReorder: (int oldIndex, int newIndex) {
            if (newIndex != oldIndex) {
              favoritesModel.move(oldIndex, newIndex);
            }
          },
          itemBuilder: (context, index) {
            final favorite = favorites[index];
            return FavoriteShortcut(
              key: Key(favorite),
              path: favorite,
              selected: favorite == _activeRoot,
              reorderIndex: index,
              onTap: () => onPathUpdated(favorite, favorite),
              onRemove: () => favoritesModel.remove(favorite),
            );
          },
        ),
      );

      sidebarContent.add(
        SliverToBoxAdapter(
          child: Section(title: AppLocalizations.of(context)!.favorites),
        ),
      );
      sidebarContent.add(SliverToBoxAdapter(child: favoritesList));
    }

    // devices
    sidebarContent.add(
      SliverToBoxAdapter(
        child: Section(title: AppLocalizations.of(context)!.devices),
      ),
    );
    for (final device in _devices) {
      sidebarContent.add(
        BrowserTree(
          key: ValueKey(device.path),
          title: device.title,
          root: device.path,
          selectedPath: device.path == _activeRoot ? historyModel.top : null,
          assetName: SystemPath.getFolderNamedAsset(device.path, isDrive: true),
          onUpdate: onPathUpdated,
          onRequestFocus: _focusNode.requestFocus,
        ),
      );
    }
    sidebarContent.add(
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    );

    // done
    return sidebarContent;
  }

  void onPathUpdated(String root, String selectedPath) {
    setState(() {
      _activeRoot = root;
    });
    widget.navigateToFolder(selectedPath);
  }
}

class FavoriteShortcut extends StatelessWidget {
  static const double rowExtent = 34;
  static const double _iconSize = 16;

  final String path;
  final bool selected;
  final int reorderIndex;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const FavoriteShortcut({
    super.key,
    required this.path,
    required this.selected,
    required this.reorderIndex,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: selected ? palette.accent : palette.primaryText,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 12,
        );
    final row = Semantics(
      button: true,
      selected: selected,
      label: Utils.pathTitle(path) ?? path,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? palette.selectionFill : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.only(
              left: 12,
              right: 8,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _iconSize,
                  height: _iconSize,
                  child: Image.asset(
                    SystemPath.getFolderNamedAsset(path),
                    width: _iconSize,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Utils.pathTitle(path) ?? path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: ReorderableDragStartListener(
                    index: reorderIndex,
                    child: Icon(
                      CupertinoIcons.bars,
                      color: selected ? palette.accent : palette.secondaryText,
                      size: _iconSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      height: rowExtent,
      child: Material(
        type: MaterialType.transparency,
        child: ctxm.ContextMenu(
          menu: ctxm.Menu(
            items: [
              ctxm.MenuItem(
                label: AppLocalizations.of(context)!.favoritesRemove,
                onClick: (_) => onRemove(),
              ),
            ],
          ),
          child: row,
        ),
      ),
    );
  }
}

class Section extends StatelessWidget {
  final String title;

  const Section({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return Container(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        top: 16,
        bottom: 8,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.secondaryText,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.7,
            ),
      ),
    );
  }
}

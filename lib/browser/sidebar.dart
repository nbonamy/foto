import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

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
        return CustomScrollView(
          controller: widget.scrollController,
          slivers: _buildSidebarSlivers(context, history, favorites),
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
      final favoritesList = SliverReorderableList(
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
          return Stack(
            key: Key(favorite),
            children: [
              BrowserTree(
                root: favorite,
                title: Utils.pathTitle(favorite),
                assetName: SystemPath.getFolderNamedAsset(favorite),
                selectedPath: favorite == _activeRoot ? historyModel.top : null,
                onUpdate: onPathUpdated,
              ),
              Positioned(
                top: 4,
                right: 12,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(
                      CupertinoIcons.bars,
                      color: Color(0xFF86838A),
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );

      sidebarContent.add(
        SliverToBoxAdapter(
          child: Section(title: AppLocalizations.of(context)!.favorites),
        ),
      );
      sidebarContent.add(favoritesList);
    }

    // devices
    sidebarContent.add(
      SliverToBoxAdapter(
        child: Section(title: AppLocalizations.of(context)!.devices),
      ),
    );
    sidebarContent.add(
      SliverList.list(
        children: [
          for (final device in _devices)
            BrowserTree(
              title: device.title,
              root: device.path,
              selectedPath:
                  device.path == _activeRoot ? historyModel.top : null,
              assetName:
                  SystemPath.getFolderNamedAsset(device.path, isDrive: true),
              onUpdate: onPathUpdated,
            ),
          const SizedBox(height: 16),
        ],
      ),
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

class Section extends StatelessWidget {
  final String title;

  const Section({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        top: 16,
        bottom: 8,
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF86838A),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

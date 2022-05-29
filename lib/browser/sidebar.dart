import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:foto/browser/tree.dart';
import 'package:foto/model/favorites.dart';
import 'package:foto/model/history.dart';
import 'package:foto/utils/paths.dart';
import 'package:foto/utils/utils.dart';
import 'package:provider/provider.dart';

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

  const BrowserSidebar({
    super.key,
    required this.scrollController,
  });

  @override
  State<StatefulWidget> createState() => _SidebarState();
}

class _SidebarState extends State<BrowserSidebar> {
  String? _activeRoot;
  final List<RootNode> _devices = [];

  @override
  void initState() {
    _getDevices();
    super.initState();
  }

  void _getDevices() {
    try {
      // list stuff in volumes
      for (var entity in Directory('/Volumes')
          .listSync(recursive: false, followLinks: false)) {
        try {
          var title = Utils.pathTitle(entity.path);
          if (entity is Directory) {
            _devices.add(RootNode(
              title,
              entity.path,
            ));
          } else if (entity is Link) {
            _devices.add(RootNode(
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
    if (_devices.indexWhere((element) => element.path == '/') == -1) {
      _devices.add(RootNode('Macintosh HD', '/'));
    }

    // now sort devices by path
    _devices.sort((a, b) => a.path.compareTo(b.path));
  }

  void _setActiveRoot(context) {
    // get data
    var history = HistoryModel.of(context);
    var favorites = Provider.of<FavoritesModel>(context, listen: false).get;

    // default active root
    _activeRoot = null;
    for (var favorite in favorites) {
      if (history.top.startsWith(favorite) == true) {
        _activeRoot = favorite;
        break;
      }
    }
    if (_activeRoot == null) {
      for (var device in _devices) {
        if (history.top.startsWith(device.path) == true) {
          _activeRoot = device.path;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // we need a root
    if (_activeRoot == null) {
      _setActiveRoot(context);
    }

    return Consumer2<HistoryModel, FavoritesModel>(
      builder: (context, history, favorites, child) => ListView(
        controller: widget.scrollController,
        children: buildSidebar(context, history, favorites),
      ),
    );
  }

  List<Widget> buildSidebar(
    BuildContext context,
    HistoryModel historyModel,
    FavoritesModel favoritesModel,
  ) {
    // sidebar content
    List<Widget> sidebarContent = [];

    // favorites
    List<String> favorites = favoritesModel.get;
    if (favorites.isNotEmpty) {
      ReorderableListView favoritesList = ReorderableListView(
        shrinkWrap: true,
        buildDefaultDragHandles: false,
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
              color: Colors.grey.shade800,
              child: child,
            ),
          );
        },
        onReorder: (int oldIndex, int newIndex) {
          if (newIndex != oldIndex) {
            favoritesModel.move(oldIndex, newIndex);
          }
        },
        children: favorites.map(
          (favorite) {
            return Stack(
              key: Key(favorite),
              children: [
                BrowserTree(
                  root: favorite,
                  title: Utils.pathTitle(favorite),
                  assetName: SystemPath.getFolderNamedAsset(favorite),
                  selectedPath:
                      favorite == _activeRoot ? historyModel.top : null,
                  onUpdate: onPathUpdated,
                ),
                Positioned(
                  top: 4,
                  right: 12,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: ReorderableDragStartListener(
                      index: favorites.indexOf(favorite),
                      child: Icon(
                        CupertinoIcons.bars,
                        color: Colors.grey.shade400,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ).toList(),
      );

      // add this
      sidebarContent.add(const Section(title: 'Favorites'));
      sidebarContent.add(favoritesList);
    }

    // devices
    sidebarContent.add(const Section(title: 'Devices'));
    for (var device in _devices) {
      sidebarContent.add(
        BrowserTree(
          title: device.title,
          root: device.path,
          selectedPath: device.path == _activeRoot ? historyModel.top : null,
          assetName: SystemPath.getFolderNamedAsset(device.path, isDrive: true),
          onUpdate: onPathUpdated,
        ),
      );
    }
    sidebarContent.add(
      const SizedBox(
        height: 16,
      ),
    );

    // done
    return sidebarContent;
  }

  void onPathUpdated(String root) async {
    setState(() {
      _activeRoot = root;
    });
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

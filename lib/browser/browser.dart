import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foto/model/favorites.dart';
import 'package:foto/utils/paths.dart';
import 'package:foto/utils/utils.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:foto/browser/tree.dart';
import 'package:foto/browser/gallery.dart';
import 'package:provider/provider.dart';

import '../model/history.dart';

class RootNode {
  final String? _title;
  final String _path;

  RootNode(this._title, this._path);

  String getTitle() {
    return _title ?? Utils.pathTitle(_path) ?? '';
  }

  String getPath() {
    return _path;
  }
}

class Browser extends StatefulWidget {
  const Browser({
    Key? key,
    required this.viewImage,
  }) : super(key: key);

  final Function viewImage;

  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> {
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
          if (kDebugMode) {
            print(e);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }

    // we need root
    if (_devices.indexWhere((element) => element.getPath() == '/') == -1) {
      _devices.add(RootNode('Macintosh HD', '/'));
    }
  }

  void _initHistory(context) {
    // get data
    var history = Provider.of<HistoryModel>(context);
    if (history.top != null) {
      return;
    }

    // start with favorites
    var favorites = Provider.of<FavoritesModel>(context).get;
    if (favorites.isNotEmpty) {
      history.push(favorites[0]);
      return;
    }

    // start with pictures
    var pictures = SystemPath.pictures();
    if (pictures != null && Directory(pictures).existsSync()) {
      history.push(pictures);
      return;
    }

    // now home
    var home = SystemPath.home();
    if (home != null && Directory(home).existsSync()) {
      history.push(home);
      return;
    }

    // devices should never be empty
    history.push(_devices[0]._path);
  }

  void _setActiveRoot(context) {
    // get data
    var history = Provider.of<HistoryModel>(context);
    var favorites = Provider.of<FavoritesModel>(context).get;

    // default active root
    _activeRoot = null;
    for (var favorite in favorites) {
      if (history.top?.startsWith(favorite) == true) {
        _activeRoot = favorite;
        break;
      }
    }
    if (_activeRoot == null) {
      for (var device in _devices) {
        if (history.top?.startsWith(device.getPath()) == true) {
          _activeRoot = device.getPath();
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // we need a path
    _initHistory(context);

    // we need a root
    if (_activeRoot == null) {
      _setActiveRoot(context);
    }

    Widget window = MacosWindow(
      sidebar: Sidebar(
        minWidth: 250,
        builder: (context, controller) {
          return Consumer2<HistoryModel, FavoritesModel>(
            builder: (context, history, favorites, child) => ListView(
              controller: controller,
              children: buildSidebar(context, history, favorites),
            ),
          );
        },
      ),
      child: Consumer<HistoryModel>(
        builder: (context, history, child) => MacosScaffold(
          toolBar: buildToolbar(history),
          children: [
            ContentArea(
              builder: (context, scrollController) => ImageGallery(
                scrollController: scrollController,
                viewImage: widget.viewImage,
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: window,
    );
  }

  ToolBar buildToolbar(HistoryModel history) {
    return ToolBar(
      title: Text(
        Utils.pathTitle(history.top) ?? '',
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      titleWidth: 256.0,
      leading: history.get.length > 1
          ? MacosBackButton(
              onPressed: () => history.pop(),
              fillColor: Colors.transparent,
            )
          : null,
      actions: [
        ToolBarIconButton(
          label: 'Toggle Sidebar',
          icon: const MacosIcon(CupertinoIcons.sidebar_left),
          onPressed: () => MacosWindowScope.of(context).toggleSidebar(),
          showLabel: true,
        ),
      ],
    );
  }

  List<Widget> buildSidebar(BuildContext context, HistoryModel historyModel,
      FavoritesModel favoritesModel) {
    // sidebar content
    List<Widget> sidebarContent = [];

    // favorites
    List<String> favorites = favoritesModel.get;
    if (favorites.isNotEmpty) {
      sidebarContent.add(const Section(title: 'Favorites'));
      for (var favorite in favorites) {
        sidebarContent.add(BrowserTree(
          root: favorite,
          title: Utils.pathTitle(favorite),
          assetName: Utils.pathTitle(favorite)?.contains("Pictures") == true
              ? "assets/img/pictures.png"
              : null,
          selectedPath: favorite == _activeRoot ? historyModel.top : null,
          onUpdate: onPathUpdated,
        ));
      }
    }

    // devices
    sidebarContent.add(const Section(title: 'Devices'));
    for (var device in _devices) {
      sidebarContent.add(
        BrowserTree(
          title: device.getTitle(),
          root: device.getPath(),
          selectedPath:
              device.getPath() == _activeRoot ? historyModel.top : null,
          assetName: "assets/img/drive.png",
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

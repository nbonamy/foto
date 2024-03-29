import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as p;

import '../model/favorites.dart';
import '../model/history.dart';
import '../model/menu_actions.dart';
import '../utils/database.dart';
import '../utils/paths.dart';
import 'content.dart';
import 'sidebar.dart';

class Browser extends StatefulWidget {
  final Function viewImages;
  final MenuActionStream menuActionStream;

  const Browser({
    Key? key,
    required this.viewImages,
    required this.menuActionStream,
  }) : super(key: key);

  @override
  State<Browser> createState() => BrowserState();
}

class BrowserState extends State<Browser> {
  BuildContext? _navigatorContext;
  final MediaDb _mediaDb = MediaDb();
  late HistoryModel _history;

  @override
  void initState() {
    _history = HistoryModel.of(context);
    _history.addListener(_onHistoryChange);
    super.initState();
  }

  @override
  void dispose() {
    _history.removeListener(_onHistoryChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // we need a path
    _initLocation(context);

    Widget window = MacosWindow(
      sidebar: Sidebar(
        minWidth: 250,
        decoration: const BoxDecoration(
          color: Color.fromRGBO(210, 207, 202, 1.0),
        ),
        builder: (context, controller) {
          return BrowserSidebar(
            scrollController: controller,
          );
        },
      ),
      child: CupertinoTabView(builder: (context) {
        _navigatorContext = context;
        return BrowserContent(
          mediaDb: _mediaDb,
          path: _history.top,
          canNavigateBack: false,
          menuActionStream: widget.menuActionStream,
          navigateToFolder: _navigateToFolder,
          viewImages: widget.viewImages,
        );
      }),
    );

    return window;
  }

  void _navigateToFolder(String path) {
    if (path == '..') {
      _history.pop();
    } else {
      _history.push(path, true);
    }
  }

  void resetHistoryWithFile(String filepath) {
    String folder = p.dirname(filepath);
    _history.reset(folder);
    Navigator.pushAndRemoveUntil(
      _navigatorContext!,
      _getContentRoute(initialSelection: [filepath]),
      (route) => false,
    );
  }

  void _onHistoryChange() {
    if (_history.lastChangeIsPop) {
      Navigator.pop(_navigatorContext!);
    } else {
      Navigator.push(
        _navigatorContext!,
        _getContentRoute(),
      );
    }
  }

  PageRoute _getContentRoute({String? path, List<String>? initialSelection}) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => BrowserContent(
        mediaDb: _mediaDb,
        path: path ?? _history.top,
        canNavigateBack: _history.get.length > 1,
        menuActionStream: widget.menuActionStream,
        initialSelection: initialSelection,
        navigateToFolder: _navigateToFolder,
        viewImages: widget.viewImages,
      ),
      transitionDuration: const Duration(seconds: 0),
      reverseTransitionDuration: const Duration(seconds: 0),
    );
  }

  void _initLocation(context) {
    // preferences
    if (_history.get.isNotEmpty) {
      return;
    }

    // start with favorites
    var favorites = FavoritesModel.of(context).get;
    if (favorites.isNotEmpty) {
      _history.push(favorites.first, false);
      return;
    }

    // start with pictures
    var pictures = SystemPath.pictures();
    if (pictures != null && Directory(pictures).existsSync()) {
      _history.push(pictures, false);
      return;
    }

    // now home
    var home = SystemPath.home();
    if (home != null && Directory(home).existsSync()) {
      _history.push(home, false);
      return;
    }

    // devices should never be empty
    _history.push('/', false);
  }
}

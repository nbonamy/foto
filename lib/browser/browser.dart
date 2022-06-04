import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:foto/browser/content.dart';
import 'package:foto/model/menu_actions.dart';
import 'package:foto/browser/sidebar.dart';
import 'package:foto/model/favorites.dart';
import 'package:foto/model/history.dart';
import 'package:foto/utils/paths.dart';
import 'package:macos_ui/macos_ui.dart';

class Browser extends StatefulWidget {
  final Function viewImages;
  final MenuActionStream menuActionStream;

  const Browser({
    Key? key,
    required this.viewImages,
    required this.menuActionStream,
  }) : super(key: key);

  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> {
  BuildContext? _navigatorContext;

  @override
  void initState() {
    HistoryModel history = HistoryModel.of(context);
    history.addListener(_onHistoryChange);
    super.initState();
  }

  @override
  void dispose() {
    HistoryModel history = HistoryModel.of(context);
    history.removeListener(_onHistoryChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // we need a path
    _initLocation(context);

    Widget window = MacosWindow(
      sidebar: Sidebar(
        minWidth: 250,
        builder: (context, controller) {
          return BrowserSidebar(
            scrollController: controller,
          );
        },
      ),
      child: CupertinoTabView(builder: (context) {
        _navigatorContext = context;
        return BrowserContent(
          path: HistoryModel.of(context).top,
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
      HistoryModel.of(context).pop();
    } else {
      HistoryModel.of(context).push(path, true);
    }
  }

  void _onHistoryChange() {
    HistoryModel history = HistoryModel.of(context);
    if (history.lastChangeIsPop) {
      Navigator.pop(_navigatorContext!);
    } else {
      Navigator.push(
        _navigatorContext!,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => BrowserContent(
            path: history.top,
            canNavigateBack: true,
            menuActionStream: widget.menuActionStream,
            navigateToFolder: _navigateToFolder,
            viewImages: widget.viewImages,
          ),
          transitionDuration: const Duration(seconds: 0),
          reverseTransitionDuration: const Duration(seconds: 0),
        ),
      );
    }
  }

  void _initLocation(context) {
    // preferences
    HistoryModel history = HistoryModel.of(context);
    if (history.get.isNotEmpty) {
      return;
    }

    // start with favorites
    var favorites = FavoritesModel.of(context).get;
    if (favorites.isNotEmpty) {
      history.push(favorites.first, false);
      return;
    }

    // start with pictures
    var pictures = SystemPath.pictures();
    if (pictures != null && Directory(pictures).existsSync()) {
      history.push(pictures, false);
      return;
    }

    // now home
    var home = SystemPath.home();
    if (home != null && Directory(home).existsSync()) {
      history.push(home, false);
      return;
    }

    // devices should never be empty
    history.push('/', false);
  }
}

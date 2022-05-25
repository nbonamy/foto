import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:foto/browser/sidebar.dart';
import 'package:foto/model/favorites.dart';
import 'package:foto/model/history.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/utils/paths.dart';
import 'package:foto/utils/utils.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:foto/browser/gallery.dart';
import 'package:provider/provider.dart';

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
    history.push('/');
  }

  @override
  Widget build(BuildContext context) {
    // we need a path
    _initHistory(context);

    Widget window = MacosWindow(
      sidebar: Sidebar(
        minWidth: 250,
        builder: (context, controller) {
          return BrowserSidebar(
            scrollController: controller,
          );
        },
      ),
      child: MacosScaffold(
        toolBar: buildToolbar(),
        children: [
          ContentArea(
            builder: (context, scrollController) => ImageGallery(
              scrollController: scrollController,
              viewImage: widget.viewImage,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: window,
    );
  }

  ToolBar buildToolbar() {
    const String tickOnPrefix = '✓';
    const String tickOffPrefix = '   ';
    Preferences prefs = Provider.of<Preferences>(context);
    HistoryModel history = Provider.of<HistoryModel>(context, listen: false);
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
        ToolBarPullDownButton(
          label: 'Actions',
          icon: CupertinoIcons.sort_down_circle,
          tooltipMessage: 'Sort',
          items: [
            MacosPulldownMenuItem(
              label: 'Alphabetical',
              title: Text(
                  '${(prefs.sortType == SortType.alphabetical) ? tickOnPrefix : tickOffPrefix} Sort Alphabetical'),
              onTap: () {
                prefs.sortType = SortType.alphabetical;
                prefs.notifyListeners();
                setState(() {});
              },
            ),
            MacosPulldownMenuItem(
              label: 'Chronological',
              title: Text(
                  '${(prefs.sortType == SortType.chronological) ? tickOnPrefix : tickOffPrefix} Sort Chronological'),
              onTap: () {
                prefs.sortType = SortType.chronological;
                prefs.notifyListeners();
                setState(() {});
              },
            ),
            const MacosPulldownMenuDivider(),
            MacosPulldownMenuItem(
              label: 'Reverse.',
              title: Text(
                  '${prefs.sortReversed ? tickOnPrefix : tickOffPrefix} Reverse Order'),
              onTap: () {
                prefs.sortReversed = !prefs.sortReversed;
                prefs.notifyListeners();
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }
}

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../components/window_shell.dart';
import '../model/favorites.dart';
import '../model/history.dart';
import '../model/menu_actions.dart';
import '../model/selection.dart';
import '../utils/database.dart';
import '../utils/paths.dart';
import 'content.dart';
import 'sidebar.dart';

class Browser extends StatefulWidget {
  final Function viewImages;
  final MenuActionStream menuActionStream;

  const Browser({
    super.key,
    required this.viewImages,
    required this.menuActionStream,
  });

  @override
  State<Browser> createState() => BrowserState();
}

class BrowserState extends State<Browser> {
  final MediaDb _mediaDb = MediaDb();
  final FocusNode _galleryFocusNode = FocusNode(debugLabel: 'browser gallery');
  final ScrollController _sidebarScrollController = ScrollController();
  final Map<String, List<String>> _selectionsByPath = {};
  late HistoryModel _history;
  List<String>? _initialSelection;
  bool _showSidebar = true;

  @override
  void initState() {
    _history = HistoryModel.of(context);
    _history.addListener(_onHistoryChange);
    super.initState();
  }

  @override
  void dispose() {
    _history.removeListener(_onHistoryChange);
    _galleryFocusNode.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // we need a path
    _initLocation(context);

    return FotoWindowShell(
      showSidebar: _showSidebar,
      sidebar: BrowserSidebar(
        scrollController: _sidebarScrollController,
        navigateToFolder: _navigateToFolder,
      ),
      child: BrowserContent(
        key: ValueKey(_history.top),
        mediaDb: _mediaDb,
        path: _history.top,
        canNavigateBack: _history.canPop,
        menuActionStream: widget.menuActionStream,
        initialSelection: _initialSelection,
        galleryFocusNode: _galleryFocusNode,
        showSidebar: _showSidebar,
        toggleSidebar: _toggleSidebar,
        navigateToFolder: _navigateToFolder,
        viewImages: widget.viewImages,
      ),
    );
  }

  void _toggleSidebar() {
    setState(() => _showSidebar = !_showSidebar);
  }

  void _navigateToFolder(String path) {
    _rememberCurrentSelection();
    if (path == '..') {
      if (!_history.canPop) return;
      final history = _history.get;
      _initialSelection = _selectionsByPath[history[history.length - 2]];
      _history.pop();
    } else {
      _initialSelection = _selectionsByPath[path];
      _history.push(path, true);
    }
  }

  void resetHistoryWithFile(String filepath) {
    final String folder = p.dirname(filepath);
    _initialSelection = [filepath];
    _selectionsByPath[folder] = [filepath];
    _history.reset(folder, notify: true);
  }

  void requestFocus() {
    _galleryFocusNode.requestFocus();
  }

  void _onHistoryChange() {
    if (mounted) setState(() {});
  }

  void _rememberCurrentSelection() {
    _selectionsByPath[_history.top] =
        SelectionModel.of(context).get.toList(growable: false);
  }

  void _initLocation(BuildContext context) {
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

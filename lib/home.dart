import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'browser/browser.dart';
import 'model/menu_actions.dart';
import 'model/preferences.dart';
import 'model/selection.dart';
import 'utils/file_handler.dart';
import 'utils/media_utils.dart';
import 'utils/platform_keyboard.dart';
import 'utils/platform_utils.dart';
import 'viewer/viewer.dart';

class Home extends StatefulWidget {
  final List<String> args;
  const Home({super.key, required this.args});

  @override
  State<StatefulWidget> createState() => _HomeState();
}

class _HomeState extends State<Home> with WindowListener {
  final GlobalKey<BrowserState> _keyBrowser = GlobalKey();
  bool _startedFromFinder = false;
  final MenuActionController _menuActionBrowserStream =
      MenuActionController.broadcast();
  final MenuActionController _menuActionViewerStream =
      MenuActionController.broadcast();
  StreamSubscription<String>? _fileSubscription;
  PageRoute<void>? _viewerRoute;
  int _openRequestGeneration = 0;
  bool _instantFullScreenActive = false;

  bool get isViewerActive => _viewerRoute?.isActive ?? false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkFile();
  }

  @override
  void dispose() {
    if (_instantFullScreenActive) {
      unawaited(PlatformUtils.exitInstantFullScreen());
    }
    windowManager.removeListener(this);
    _fileSubscription?.cancel();
    _menuActionBrowserStream.close();
    _menuActionViewerStream.close();
    super.dispose();
  }

  void _checkFile() async {
    try {
      // subscribe to stream
      _fileSubscription = getFilesStream()?.listen(
        viewImage,
        onError: (_) {},
      );

      // initial file
      String? initialFile = await getInitialFile();
      if (initialFile == null && widget.args.isNotEmpty) {
        initialFile = widget.args[0];
      }

      // view
      if (mounted && initialFile != null && File(initialFile).existsSync()) {
        _startedFromFinder = true;
        viewImage(initialFile);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: _getMainMenu(context),
      child: Browser(
        key: _keyBrowser,
        viewImages: viewImages,
        menuActionStream: _menuActionBrowserStream.stream,
      ),
    );
  }

  List<PlatformMenuItem> _getMainMenu(BuildContext context) {
    AppLocalizations t = AppLocalizations.of(context)!;
    return [
      PlatformMenu(
        label: t.appName,
        menus: [
          const PlatformProvidedMenuItem(
            type: PlatformProvidedMenuItemType.about,
          ),
          const PlatformProvidedMenuItem(
            type: PlatformProvidedMenuItemType.quit,
          ),
        ],
      ),
      PlatformMenu(
        label: t.menuFile,
        menus: [
          PlatformMenuItem(
            label: t.menuFileRefresh,
            shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyR),
            onSelected: () => _onMenu(MenuAction.fileRefresh),
          ),
          PlatformMenuItem(
            label: t.menuFileRename,
            //shortcut: const SingleActivator(LogicalKeyboardKey.enter),
            onSelected: () => _onMenu(MenuAction.fileRename),
          ),
        ],
      ),
      PlatformMenu(
        label: t.menuEdit,
        menus: [
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: t.menuEditSelectAll,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyA),
                onSelected: () => _onMenu(MenuAction.editSelectAll),
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: isViewerActive ? t.menuImageCopy : t.menuEditCopyItems,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyC),
                onSelected: () => _onMenu(MenuAction.editCopy),
              ),
              if (!isViewerActive)
                PlatformMenuItem(
                  label: t.menuImageCopy,
                  shortcut: MenuUtils.cmdShiftShortcut(LogicalKeyboardKey.keyC),
                  onSelected: () => _onMenu(MenuAction.imageCopy),
                ),
              PlatformMenuItem(
                label: t.menuEditPaste,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyV),
                onSelected: () => _onMenu(MenuAction.editPaste),
              ),
              PlatformMenuItem(
                label: t.menuEditPasteMove,
                shortcut: SingleActivator(
                  LogicalKeyboardKey.keyV,
                  alt: true,
                  control: PlatformKeyboard.ctrlIsCommandModifier(),
                  meta: PlatformKeyboard.metaIsCommandModifier(),
                ),
                onSelected: () => _onMenu(MenuAction.editPasteMove),
              ),
              PlatformMenuItem(
                label: t.menuEditDelete,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.backspace),
                onSelected: () => _onMenu(MenuAction.editDelete),
              ),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: t.menuImage,
        menus: [
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: t.menuImageView,
                shortcut: const SingleActivator(LogicalKeyboardKey.enter),
                onSelected: () => _onMenu(MenuAction.imageView),
              ),
            ],
          ),
          PlatformMenu(
            label: t.menuImageTransform,
            menus: [
              PlatformMenuItem(
                label: t.menuImageRotate90CW,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.arrowRight),
                onSelected: () => _onMenu(MenuAction.imageRotate90cw),
              ),
              PlatformMenuItem(
                label: t.menuImageRotate90CCW,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.arrowLeft),
                onSelected: () => _onMenu(MenuAction.imageRotate90ccw),
              ),
              PlatformMenuItem(
                label: t.menuImageRotate180,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.arrowDown),
                onSelected: () => _onMenu(MenuAction.imageRotate180),
              ),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: t.menuView,
        menus: [
          PlatformMenuItem(
            label: t.menuViewInspector,
            shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyI),
            onSelected: () => _onMenu(MenuAction.viewInspector),
          ),
        ],
      ),
    ];
  }

  void _onMenu(MenuAction action) {
    final MenuActionController controller =
        isViewerActive ? _menuActionViewerStream : _menuActionBrowserStream;
    controller.sink.add(action);
  }

  Future<void> viewImage(String image) async {
    final int requestGeneration = ++_openRequestGeneration;
    try {
      final File file = File(image);
      if (!file.existsSync()) {
        return;
      }
      final String normalizedImage = file.absolute.path;
      final String path = file.parent.absolute.path;
      var items = await MediaUtils.getMediaFiles(
        null,
        path,
        includeDirs: false,
        sortCriteria: SortCriteria.alphabetical,
      );
      if (!mounted || requestGeneration != _openRequestGeneration) {
        return;
      }
      var images = items.map<String>((e) => e.path).toList();
      var index = images.indexOf(normalizedImage);
      if (index == -1) {
        // Hidden images and new files may not be in the directory scan yet.
        images = <String>[normalizedImage];
        index = 0;
      }
      await viewImages(images, index);
    } catch (_) {
      // Finder events can race file moves and removals.
    }
  }

  Future<void> viewImages(List<String> images, int startIndex) async {
    final String? requestedImage = startIndex >= 0 && startIndex < images.length
        ? images[startIndex]
        : null;
    final List<String> viewerImages = LinkedHashSet<String>.from(
      images.where((image) => image.isNotEmpty),
    ).toList(growable: false);
    if (!mounted || viewerImages.isEmpty) {
      return;
    }
    final int viewerStart = requestedImage == null
        ? 0
        : max(0, viewerImages.indexOf(requestedImage));

    final PageRoute<void>? previousRoute = _viewerRoute;
    final NavigatorState navigator = Navigator.of(context);
    if (previousRoute != null && previousRoute.isActive) {
      navigator.popUntil(
        (route) => identical(route, previousRoute) || route.isFirst,
      );
      if (previousRoute.isActive) {
        navigator.removeRoute(previousRoute);
      }
    }

    final PageRoute<void> route = PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/viewer'),
      pageBuilder: (_, __, ___) => ImageViewer(
        images: viewerImages,
        start: viewerStart,
        menuActionStream: _menuActionViewerStream.stream,
        exit: closeViewer,
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
    _viewerRoute = route;
    final routeClosed = navigator.push(route);
    if (mounted) {
      setState(() {});
    }
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && route.isActive && identical(_viewerRoute, route)) {
      await _enterInstantFullScreen();
    }
    try {
      await routeClosed;
    } finally {
      if (identical(_viewerRoute, route)) {
        _viewerRoute = null;
        if (mounted) {
          setState(() {});
        }
        await _exitInstantFullScreen();
        _restoreBrowserFocus();
      }
    }
  }

  void closeViewer({String? current, bool? quit = false}) {
    unawaited(_closeViewer(current: current, quit: quit));
  }

  Future<void> _closeViewer({String? current, bool? quit = false}) async {
    await _exitInstantFullScreen();
    if (!mounted) return;

    if (_startedFromFinder) {
      _startedFromFinder = false;
      if (quit == true) {
        await SystemNavigator.pop();
        return;
      } else if (current != null) {
        _popViewer();
        _keyBrowser.currentState?.resetHistoryWithFile(current);
        return;
      }
    }

    // selection
    if (quit == false && current != null) {
      SelectionModel selectionModel = SelectionModel.of(context);
      if (selectionModel.get.length == 1) {
        selectionModel.set([current]);
      }
    }

    // default
    _popViewer();
  }

  Future<void> _enterInstantFullScreen() async {
    if (_instantFullScreenActive) return;
    _instantFullScreenActive = true;
    try {
      await PlatformUtils.enterInstantFullScreen();
    } catch (error) {
      _instantFullScreenActive = false;
      debugPrint('Unable to enter instant fullscreen: $error');
    }
  }

  Future<void> _exitInstantFullScreen() async {
    if (!_instantFullScreenActive) return;
    try {
      await PlatformUtils.exitInstantFullScreen();
    } catch (error) {
      debugPrint('Unable to exit instant fullscreen: $error');
    } finally {
      _instantFullScreenActive = false;
    }
  }

  void _popViewer() {
    final PageRoute<void>? route = _viewerRoute;
    if (route?.isActive == true) {
      Navigator.of(context).removeRoute(route!);
    }
  }

  void _restoreBrowserFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !isViewerActive) {
        _keyBrowser.currentState?.requestFocus();
      }
    });
  }

  @override
  void onWindowMoved() async {
    if (_instantFullScreenActive) return;
    final bool fullScreen = await windowManager.isFullScreen();
    if (mounted && !fullScreen) {
      _saveWindowBounds();
    }
  }

  @override
  void onWindowResized() async {
    if (_instantFullScreenActive) return;
    final bool fullScreen = await windowManager.isFullScreen();
    if (mounted && !fullScreen) {
      _saveWindowBounds();
    }
  }

  void _saveWindowBounds() async {
    if (_instantFullScreenActive) return;
    final Rect rc = await windowManager.getBounds();
    if (!mounted || _instantFullScreenActive) return;
    final bool fullScreen = await windowManager.isFullScreen();
    if (!mounted || fullScreen || !_isValidWindowBounds(rc)) {
      return;
    }
    Preferences.of(context).windowBounds = rc;
  }

  bool _isValidWindowBounds(Rect bounds) {
    return bounds.left.isFinite &&
        bounds.top.isFinite &&
        bounds.right.isFinite &&
        bounds.bottom.isFinite &&
        bounds.width >= 320 &&
        bounds.height >= 240;
  }
}

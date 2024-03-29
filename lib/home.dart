import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'browser/browser.dart';
import 'model/menu_actions.dart';
import 'model/preferences.dart';
import 'model/selection.dart';
import 'utils/file_handler.dart';
import 'utils/media_utils.dart';
import 'utils/platform_keyboard.dart';
import 'viewer/viewer.dart';

class Home extends StatefulWidget {
  final List<String> args;
  const Home({Key? key, required this.args}) : super(key: key);

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

  Future<bool> get isViewerActive async {
    return windowManager.isFullScreen();
  }

  @override
  void initState() {
    windowManager.addListener(this);
    _checkFile();
    super.initState();
  }

  void _checkFile() async {
    try {
      // subscribe to stream
      getFilesStream()?.listen((String file) {
        viewImage(Uri.decodeComponent(file));
      }, onError: (err) {});

      // initial file
      String? initialFile = await getInitialFile();
      if (initialFile != null) {
        initialFile = Uri.decodeComponent(initialFile);
      } else if (widget.args.isNotEmpty) {
        initialFile = widget.args[0];
      }

      // view
      if (initialFile != null) {
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
                label: t.menuEditCopy,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyC),
                onSelected: () => _onMenu(MenuAction.editCopy),
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
    isViewerActive.then((active) {
      MenuActionController controller =
          active ? _menuActionViewerStream : _menuActionBrowserStream;
      controller.sink.add(action);
    });
  }

  void viewImage(String image) async {
    var path = File(image).parent.path;
    var items = await MediaUtils.getMediaFiles(
      null,
      path,
      includeDirs: false,
      sortCriteria: SortCriteria.alphabetical,
    );
    var images = items.map<String>((e) => e.path).toList();
    var index = images.indexOf(image);
    viewImages(images, index);
  }

  void viewImages(List<String> images, int startIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        settings: const RouteSettings(name: '/viewer'),
        pageBuilder: (_, __, ___) => ImageViewer(
          images: images,
          start: startIndex,
          menuActionStream: _menuActionViewerStream.stream,
          exit: closeViewer,
        ),
        transitionDuration: const Duration(seconds: 0),
        reverseTransitionDuration: const Duration(seconds: 0),
      ),
    );
    windowManager.setFullScreen(true);
  }

  void closeViewer({String? current, bool? quit = false}) {
    windowManager.setFullScreen(false);
    if (_startedFromFinder) {
      _startedFromFinder = false;
      if (quit == true) {
        SystemNavigator.pop();
        return;
      } else if (current != null) {
        Navigator.pop(context);
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
    Navigator.pop(context);
  }

  @override
  void onWindowMoved() async {
    if (!await windowManager.isFullScreen()) {
      _saveWindowBounds();
    }
  }

  @override
  void onWindowResized() async {
    if (!await windowManager.isFullScreen()) {
      _saveWindowBounds();
    }
  }

  void _saveWindowBounds() async {
    Rect rc = await windowManager.getBounds();
    // ignore: use_build_context_synchronously
    Preferences.of(context).windowBounds = rc;
  }
}

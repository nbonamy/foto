import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:foto/model/menu_actions.dart';
import 'package:foto/utils/file_handler.dart';
import 'package:foto/utils/media_utils.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/utils/platform_keyboard.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:foto/browser/browser.dart';
import 'package:foto/viewer/viewer.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Home extends StatefulWidget {
  final List<String> args;
  const Home({Key? key, required this.args}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _HomeState();
}

class _HomeState extends State<Home> with WindowListener {
  GlobalKey<BrowserState> _keyBrowser = GlobalKey();
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
      body: Browser(
        key: _keyBrowser,
        viewImages: viewImages,
        menuActionStream: _menuActionBrowserStream.stream,
      ),
    );
  }

  List<MenuItem> _getMainMenu(BuildContext context) {
    return [
      PlatformMenu(
        label: AppLocalizations.of(context)!.appName,
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
        label: AppLocalizations.of(context)!.menuFile,
        menus: [
          PlatformMenuItem(
            label: AppLocalizations.of(context)!.menuFileRefresh,
            shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyR),
            onSelected: () => _onMenu(MenuAction.fileRefresh),
          ),
          PlatformMenuItem(
            label: AppLocalizations.of(context)!.menuFileRename,
            //shortcut: const SingleActivator(LogicalKeyboardKey.enter),
            onSelected: () => _onMenu(MenuAction.fileRename),
          ),
        ],
      ),
      PlatformMenu(
        label: AppLocalizations.of(context)!.menuEdit,
        menus: [
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: AppLocalizations.of(context)!.menuEditSelectAll,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyA),
                onSelected: () => _onMenu(MenuAction.editSelectAll),
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: AppLocalizations.of(context)!.menuEditCopy,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyC),
                onSelected: () => _onMenu(MenuAction.editCopy),
              ),
              PlatformMenuItem(
                label: AppLocalizations.of(context)!.menuEditPaste,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.keyV),
                onSelected: () => _onMenu(MenuAction.editPaste),
              ),
              PlatformMenuItem(
                label: AppLocalizations.of(context)!.menuEditDelete,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.backspace),
                onSelected: () => _onMenu(MenuAction.editDelete),
              ),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: AppLocalizations.of(context)!.menuImage,
        menus: [
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: AppLocalizations.of(context)!.menuImageView,
                onSelected: () => _onMenu(MenuAction.imageView),
              ),
            ],
          ),
          PlatformMenu(
            label: AppLocalizations.of(context)!.menuImageTransform,
            menus: [
              PlatformMenuItem(
                label: AppLocalizations.of(context)!.menuImageRotate90CW,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.arrowRight),
                onSelected: () => _onMenu(MenuAction.imageRotate90cw),
              ),
              PlatformMenuItem(
                label: AppLocalizations.of(context)!.menuImageRotate90CCW,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.arrowLeft),
                onSelected: () => _onMenu(MenuAction.imageRotate90ccw),
              ),
              PlatformMenuItem(
                label: AppLocalizations.of(context)!.menuImageRotate180,
                shortcut: MenuUtils.cmdShortcut(LogicalKeyboardKey.arrowDown),
                onSelected: () => _onMenu(MenuAction.imageRotate180),
              ),
            ],
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

  void viewImage(String image) {
    var path = File(image).parent.path;
    var images = MediaUtils.getMediaFiles(path, includeDirs: false)
        .map<String>((e) => e.path)
        .toList();
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

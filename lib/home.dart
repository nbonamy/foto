import 'dart:io';

import 'package:flutter/services.dart';
import 'package:foto/utils/file_handler.dart';
import 'package:foto/utils/media.dart';
import 'package:foto/model/preferences.dart';
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
  bool _startedFromFinder = false;

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
      menus: [
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
          label: AppLocalizations.of(context)!.menuEdit,
          menus: [
            //_menuItem('Copy', LogicalKeyboardKey.keyC),
            //_menuItem('Paste', LogicalKeyboardKey.keyV),
          ],
        ),
        PlatformMenu(
          label: AppLocalizations.of(context)!.menuView,
          menus: [
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
        PlatformMenu(
          label: AppLocalizations.of(context)!.menuWindow,
          menus: [
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
          ],
        ),
      ],
      body: Browser(
        viewImages: viewImages,
      ),
    );
  }

  void viewImage(String image) {
    var path = File(image).parent.path;
    var images = Media.getMediaFiles(path, includeDirs: false)
        .map<String>((e) => e.path)
        .toList();
    var index = images.indexOf(image);
    viewImages(images, index);
  }

  void viewImages(List<String> images, int startIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ImageViewer(
          images: images,
          start: startIndex,
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
    if (quit == true && _startedFromFinder == true) {
      SystemNavigator.pop();
    } else {
      Navigator.pop(context);
    }
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

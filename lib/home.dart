import 'dart:io';
import 'package:foto/utils/file_handler.dart';
import 'package:foto/utils/media.dart';
import 'package:foto/utils/preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:foto/browser/browser.dart';
import 'package:foto/viewer/viewer.dart';

class Home extends StatefulWidget {
  final List<String> args;
  const Home({Key? key, required this.args}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _HomeState();
}

class _HomeState extends State<Home> with WindowListener {
  List<String>? _images;
  int? _startIndex;

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
        viewImage(initialFile);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_images == null) {
      return Browser(
        viewImage: viewImage,
      );
    } else {
      return ImageViewer(
        images: _images!,
        start: _startIndex!,
        exit: closeViewer,
      );
    }
  }

  void viewImage(String image) {
    var path = File(image).parent.path;
    var images =
        Media.getMediaFiles(path, false).map<String>((e) => e.path).toList();
    var index = images.indexOf(image);
    viewImages(images, index);
  }

  void viewImages(List<String> images, int startIndex) {
    setState(() {
      _images = images;
      _startIndex = startIndex;
    });
    windowManager.setFullScreen(true);
  }

  void closeViewer({String? current}) {
    setState(() {
      _images = null;
    });
    windowManager.setFullScreen(false);
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() {
      _images = null;
    });
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
    Preferences.saveWindowBounds(rc);
  }
}

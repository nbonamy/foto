import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class FileUtils {
  static Future confirmDelete(BuildContext context, List<String> files) {
    String text = files.length == 1
        ? 'Are you sure you want to delete this image? This cannot be undone.'
        : 'Are you sure you want to delete these images? This cannot be undone.';

    return showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: Image.asset(
          'assets/img/foto.png',
          width: 56,
          height: 56,
        ),
        title: Text(
          'foto',
          style: MacosTheme.of(context).typography.title3,
        ),
        message: Text(
          text,
          textAlign: TextAlign.center,
          style: MacosTheme.of(context).typography.body,
        ),
        primaryButton: PushButton(
          buttonSize: ButtonSize.small,
          color: Colors.red,
          onPressed: () {
            delete(files).then((value) {
              Navigator.of(context).pop(true);
            }).onError((error, stackTrace) {
              Navigator.of(context).pop();
            });
          },
          child: const Text('Yes'),
        ),
        secondaryButton: PushButton(
          isSecondary: true,
          buttonSize: ButtonSize.small,
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  static Future delete(List<String> files) {
    List<Future> futures = [];
    for (var file in files) {
      futures.add(File(file).delete());
    }
    return Future.wait(futures);
  }
}

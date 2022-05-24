import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/utils/dialogs.dart';
import 'package:path/path.dart' as p;

class FileUtils {
  static Future confirmDelete(BuildContext context, List<String> files) {
    String text = files.length > 1
        ? 'Are you sure you want to delete these images? This cannot be undone.'
        : (FileSystemEntity.typeSync(files[0]) ==
                FileSystemEntityType.directory)
            ? 'Are you sure you want to delete this folder? This cannot be undone.'
            : 'Are you sure you want to delete this image? This cannot be undone.';

    return FotoDialog.confirm(
      context: context,
      text: text,
      onConfirmed: () {
        delete(files).then((value) {
          Navigator.of(context).pop(true);
        }).onError((error, stackTrace) {
          Navigator.of(context).pop();
        });
      },
      isDanger: true,
    );
  }

  static Future delete(List<String> files) {
    List<Future> futures = [];
    for (var file in files) {
      futures.add(File(file).delete());
    }
    return Future.wait(futures);
  }

  static Future tryCopy(
      BuildContext context, List<String> files, String destination) {
    bool conflicts = false;
    Map<String, String> operations = {};
    for (var file in files) {
      var target = destination;
      target = p.join(target, p.basename(file));
      operations[file] = target;
      if (File(target).existsSync()) {
        conflicts = true;
      }
    }

    if (conflicts) {
      return FotoDialog.confirm(
        context: context,
        text:
            'Destination file(s) already exists. Do you want to overwrite them?',
        onConfirmed: () {
          Navigator.of(context).pop();
          copy(operations);
        },
        isDanger: true,
      );
    } else {
      return copy(operations);
    }
  }

  static Future copy(Map<String, String> operations) {
    List<Future> futures = [];
    operations.forEach((src, dst) {
      futures.add(File(src).copy(dst));
    });
    return Future.wait(futures);
  }
}

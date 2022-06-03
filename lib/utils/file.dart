import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/components/dialogs.dart';
import 'package:foto/utils/platform_utils.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FileUtils {
  static Future confirmDelete(BuildContext context, List<String> files) {
    var t = AppLocalizations.of(context)!;
    String title = files.length == 1
        ? t.deleteTitleSingle(p.basename(files[0]))
        : t.deleteTitleMultiple(files.length);
    String text = t.deleteText(files.length);

    return FotoDialog.confirm(
      context: context,
      title: title,
      text: text,
      //isDestructive: true,
      confirmLabel: AppLocalizations.of(context)?.delete,
      onConfirmed: (context) {
        delete(files).then((value) {
          Navigator.of(context).pop(true);
        }).onError((error, stackTrace) {
          Navigator.of(context).pop();
        });
      },
    );
  }

  static Future delete(List<String> files) {
    List<Future> futures = [];
    for (var file in files) {
      futures.add(PlatformUtils.moveToTrash(file));
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
        text: AppLocalizations.of(context)!.overwriteConfirm,
        isDestructive: true,
        onConfirmed: (context) {
          Navigator.of(context).pop();
          copy(operations);
        },
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

  static bool tryRename(
    String originalName,
    String newName,
  ) {
    if (!newName.contains('/')) {
      newName = p.join(p.dirname(originalName), newName);
    }
    if (File(newName).existsSync()) {
      return false;
    } else {
      File(originalName).rename(newName);
      return true;
    }
  }
}

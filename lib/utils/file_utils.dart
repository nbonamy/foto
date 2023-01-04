import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;

import '../components/dialogs.dart';
import 'platform_utils.dart';

class FileUtils {
  static const MethodChannel _mChannel =
      MethodChannel('foto_file_utils/messages');

  static Future<DateTime> getCreationDate(String filepath) async {
    double epoch = await _mChannel.invokeMethod('getCreationDate', filepath);
    return DateTime.fromMillisecondsSinceEpoch(epoch.toInt() * 1000);
  }

  static Future<DateTime> getModificationDate(String filepath) async {
    double epoch =
        await _mChannel.invokeMethod('getModificationDate', filepath);
    return DateTime.fromMillisecondsSinceEpoch(epoch.toInt() * 1000);
  }

  static Future confirmDelete(
    BuildContext context,
    List<String> files, {
    Color? barrierColor,
  }) {
    var t = AppLocalizations.of(context)!;
    String title = files.length == 1
        ? t.deleteTitleSingle(p.basename(files[0]))
        : t.deleteTitleMultiple(files.length);
    String text = t.deleteText(files.length);

    return FotoDialog.confirm(
      context: context,
      barrierColor: barrierColor,
      title: title,
      text: text,
      //isDestructive: true,
      confirmLabel: AppLocalizations.of(context)?.menuEditDelete,
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

  static Future tryPaste(BuildContext context, String destination, bool move) {
    return Pasteboard.files().then((files) {
      FileUtils.tryCopyOrMove(context, files, destination, move);
    });
  }

  static Future tryCopyOrMove(
      BuildContext context, List<String> files, String destination, bool move) {
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
          _copyOrMove(operations, move);
        },
      );
    } else {
      return _copyOrMove(operations, move);
    }
  }

  static Future _copyOrMove(Map<String, String> operations, bool move) {
    return _copy(operations).then((dynamic) {
      if (move) {
        for (var file in operations.keys) {
          File(file).delete();
        }
      }
    });
  }

  static Future _copy(Map<String, String> operations) {
    List<Future> futures = [];
    operations.forEach((src, dst) {
      futures.add(File(src).copy(dst));
    });
    return Future.wait(futures);
  }

  static String? tryRename(
    String originalName,
    String newName,
  ) {
    try {
      if (!newName.contains('/')) {
        newName = p.join(p.dirname(originalName), newName);
      }
      if (File(newName).existsSync()) {
        return null;
      } else {
        File(originalName).renameSync(newName);
        return newName;
      }
    } catch (_) {
      return null;
    }
  }
}

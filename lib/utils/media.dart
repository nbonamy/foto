import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class Media {
  static String getExtension(String file) {
    return file.split('.').last.toLowerCase();
  }

  static bool isImage(String file) {
    return ['jpg', 'jpeg', 'heic', 'png', 'gif', 'tif', 'tiff']
        .contains(Media.getExtension(file));
  }

  static bool shouldExcludeFileOrDir(String fullpath) {
    String basename = p.basename(fullpath);
    return basename.startsWith(".") ||
        Media._excludedFilenames.contains(basename);
  }

  static List<FileSystemEntity> getMediaFiles(String? path, bool includeDirs) {
    try {
      // null
      if (path == null) {
        return [];
      }

      // get files
      final dir = Directory(path);
      var entities = dir.listSync(recursive: false);
      var filtered = entities.where((entity) {
        if (Media.shouldExcludeFileOrDir(entity.path)) {
          return false;
        } else if (entity is Directory) {
          return includeDirs;
        } else if (entity is File) {
          return Media.isImage(entity.path);
        } else {
          return false;
        }
      }).toList();
      filtered.sort((a, b) {
        if (a is Directory && b is! Directory) {
          return -1;
        } else if (b is Directory && a is! Directory) {
          return 1;
        } else {
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        }
      });
      return filtered;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return [];
    }
  }

  static final List<String> _excludedFilenames = ["\$RECYCLE.BIN"];
}

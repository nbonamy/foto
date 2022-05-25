import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:foto/model/preferences.dart';
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
    return basename.startsWith('.') ||
        Media._excludedFilenames.contains(basename);
  }

  static List<FileSystemEntity> getMediaFiles(
    String? path, {
    required bool includeDirs,
    SortType sortType = SortType.chronological,
    bool sortReversed = false,
  }) {
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
        if (a is Directory && b is Directory) {
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        } else if (a is Directory && b is! Directory) {
          return -1;
        } else if (b is Directory && a is! Directory) {
          return 1;
        } else {
          if (sortType == SortType.alphabetical) {
            return (sortReversed ? -1 : 1) *
                a.path.toLowerCase().compareTo(b.path.toLowerCase());
          } else if (sortType == SortType.chronological) {
            return (sortReversed ? -1 : 1) *
                a.statSync().changed.compareTo(b.statSync().changed);
          } else {
            return -1;
          }
        }
      });
      return filtered;
    } catch (e) {
      debugPrint(e.toString());
      return [];
    }
  }

  static final List<String> _excludedFilenames = ['\$RECYCLE.BIN'];
}

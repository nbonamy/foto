import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:foto/model/media.dart';
import 'package:foto/model/preferences.dart';
import 'package:path/path.dart' as p;

class MediaUtils {
  static String getExtension(String file) {
    return file.split('.').last.toLowerCase();
  }

  static bool isImage(String file) {
    return ['jpg', 'jpeg', 'heic', 'png', 'gif', 'tif', 'tiff']
        .contains(MediaUtils.getExtension(file));
  }

  static bool shouldExcludeFileOrDir(String fullpath) {
    String basename = p.basename(fullpath);
    return basename.startsWith('.') ||
        MediaUtils._excludedFilenames.contains(basename);
  }

  static List<MediaItem> getMediaFiles(
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
      List<FileSystemEntity> entities = dir.listSync(recursive: false);
      List<MediaItem> filtered = entities.where((entity) {
        if (MediaUtils.shouldExcludeFileOrDir(entity.path)) {
          return false;
        } else if (entity is Directory) {
          return includeDirs;
        } else if (entity is File) {
          return MediaUtils.isImage(entity.path);
        } else {
          return false;
        }
      }).map<MediaItem>((entity) {
        return MediaItem.forEntity(entity);
      }).toList();
      filtered.sort((a, b) {
        if (a.isDir() && b.isDir()) {
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        } else if (a.isDir() && !b.isDir()) {
          return -1;
        } else if (b.isDir() && !a.isDir()) {
          return 1;
        } else {
          if (sortType == SortType.alphabetical) {
            return (sortReversed ? -1 : 1) *
                a.path.toLowerCase().compareTo(b.path.toLowerCase());
          } else if (sortType == SortType.chronological) {
            return (sortReversed ? -1 : 1) *
                a.creationDate.compareTo(b.creationDate);
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

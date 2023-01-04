import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../model/media.dart';
import '../model/preferences.dart';
import 'database.dart';

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

  static Future<List<MediaItem>> getMediaFiles(
    MediaDb? mediaDb,
    String? path, {
    required bool includeDirs,
    SortCriteria sortCriteria = SortCriteria.chronological,
    bool sortReversed = false,
  }) async {
    try {
      // null
      if (path == null) {
        return [];
      }

      // get files
      final dir = Directory(path);
      List<FileSystemEntity> entities = dir.listSync(recursive: false);
      List<FileSystemEntity> filtered = entities.where((entity) {
        if (MediaUtils.shouldExcludeFileOrDir(entity.path)) {
          return false;
        } else if (entity is Directory) {
          return includeDirs;
        } else if (entity is File) {
          return MediaUtils.isImage(entity.path);
        } else {
          return false;
        }
      }).toList();

      // now convert to media items using database
      List<MediaItem> items = [];
      for (var entity in filtered) {
        if (mediaDb != null) {
          MediaItem mediaItem = await mediaDb.get(entity.path);
          items.add(mediaItem);
        } else {
          items.add(await MediaItem.forEntity(entity));
        }
      }

      // now sort
      items.sort((a, b) {
        if (a.isDir() && b.isDir()) {
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        } else if (a.isDir() && !b.isDir()) {
          return -1;
        } else if (b.isDir() && !a.isDir()) {
          return 1;
        } else {
          if (sortCriteria == SortCriteria.alphabetical) {
            return (sortReversed ? -1 : 1) *
                a.path.toLowerCase().compareTo(b.path.toLowerCase());
          } else if (sortCriteria == SortCriteria.chronological) {
            return (sortReversed ? -1 : 1) *
                a.creationDate.compareTo(b.creationDate);
          } else {
            return -1;
          }
        }
      });

      // done
      return items;
    } catch (e) {
      debugPrint(e.toString());
      return [];
    }
  }

  static final List<String> _excludedFilenames = ['\$RECYCLE.BIN'];
}

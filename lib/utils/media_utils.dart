import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../model/media.dart';
import '../model/preferences.dart';
import 'database.dart';
import 'file_utils.dart';

class MediaUtils {
  static const Set<String> imageExtensions = {
    'jpg',
    'jpeg',
    'heic',
    'png',
    'gif',
    'tif',
    'tiff',
    'webp',
  };

  static String getExtension(String file) {
    return p.extension(file).replaceFirst('.', '').toLowerCase();
  }

  static bool isImage(String file) {
    return imageExtensions.contains(MediaUtils.getExtension(file));
  }

  static bool shouldExcludeFileOrDir(String fullpath) {
    String basename = p.basename(fullpath);
    return basename.startsWith('.') ||
        MediaUtils._excludedFilenames.contains(basename);
  }

  static bool isPathAtOrBelow(String path, String root) {
    final normalizedPath = p.normalize(p.absolute(path));
    final normalizedRoot = p.normalize(p.absolute(root));
    return normalizedPath == normalizedRoot ||
        p.isWithin(normalizedRoot, normalizedPath);
  }

  static String? deepestContainingRoot(String path, Iterable<String> roots) {
    final matches = roots.where((root) => isPathAtOrBelow(path, root)).toList();
    matches.sort((a, b) => p
        .normalize(p.absolute(b))
        .length
        .compareTo(p.normalize(p.absolute(a)).length));
    return matches.isEmpty ? null : matches.first;
  }

  static void sortMediaItems(
    List<MediaItem> items, {
    required SortCriteria sortCriteria,
    required bool sortReversed,
  }) {
    items.sort((a, b) {
      if (a.isDir() && b.isDir()) {
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      } else if (a.isDir()) {
        return -1;
      } else if (b.isDir()) {
        return 1;
      }

      final direction = sortReversed ? -1 : 1;
      final comparison = sortCriteria == SortCriteria.alphabetical
          ? a.path.toLowerCase().compareTo(b.path.toLowerCase())
          : a.creationDate.compareTo(b.creationDate);
      if (comparison != 0) {
        return direction * comparison;
      }
      return direction * a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
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

      final entries = await FileUtils.scanDirectory(path);
      final filtered = entries.where((entry) {
        if (MediaUtils.shouldExcludeFileOrDir(entry.path)) {
          return false;
        } else if (entry.entityType == FileSystemEntityType.directory) {
          return includeDirs;
        } else if (entry.entityType == FileSystemEntityType.file) {
          return MediaUtils.isImage(entry.path);
        } else {
          return false;
        }
      }).toList();

      final items = filtered
          .map((entry) =>
              mediaDb?.getScanned(entry) ?? MediaItem.forMetadata(entry))
          .toList();

      sortMediaItems(
        items,
        sortCriteria: sortCriteria,
        sortReversed: sortReversed,
      );

      // done
      return items;
    } catch (e) {
      debugPrint(e.toString());
      return [];
    }
  }

  static final List<String> _excludedFilenames = ['\$RECYCLE.BIN'];
}

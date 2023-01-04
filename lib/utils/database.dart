import 'dart:io';

import '../model/media.dart';

class MediaDb {
  final Map<String, MediaItem> _cache = {};

  Future<MediaItem> get(String filepath) async {
    FileSystemEntityType entityType = await FileSystemEntity.type(filepath);
    if (entityType != FileSystemEntityType.file) {
      return MediaItem.forFolder(filepath);
    }

    // check if it exists
    DateTime lastModified = await File(filepath).lastModified();
    if (_cache.containsKey(filepath)) {
      MediaItem info = _cache[filepath]!;
      if (info.modificationDate == lastModified) {
        return info;
      }
    }

    // create info
    MediaItem info = await MediaItem.forFile(filepath);

    // store and return
    _cache[filepath] = info;
    return info;
  }
}

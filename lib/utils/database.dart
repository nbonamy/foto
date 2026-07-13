import 'dart:io';

import '../model/file_metadata.dart';
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

  MediaItem getScanned(FileMetadata metadata) {
    final cached = _cache[metadata.path];
    final sizeMatches = cached?.fileSize == null ||
        metadata.size == null ||
        cached?.fileSize == metadata.size;
    if (cached != null &&
        cached.entityType == metadata.entityType &&
        cached.modificationDate == metadata.modificationDate &&
        sizeMatches) {
      cached.fileSize ??= metadata.size;
      return cached;
    }

    final media = MediaItem.forMetadata(metadata);
    _cache[metadata.path] = media;
    return media;
  }
}

import 'dart:io';

import 'package:foto/model/media.dart';
import 'package:foto/utils/image_utils.dart';

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

    // get other data
    DateTime creationDate = await ImageUtils.getCreationDate(filepath);

    // create info
    MediaItem info = MediaItem.forFile(
      filepath,
      creationDate: creationDate,
      modificationDate: lastModified,
    );

    // store and return
    _cache[filepath] = info;
    return info;
  }
}

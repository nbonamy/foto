import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:foto/model/media.dart';
import 'package:foto/utils/image_utils.dart';
import 'package:foto/utils/paths.dart';
import 'package:foto/utils/utils.dart';

class MediaDb {
  static final Map<String, MediaItem> _cache = {};

  Future<MediaItem?> _get(String filepath) async {
    return null;

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

    // thumbnail
    Image thumbnail = Image.file(
      File(filepath),
      height: 160,
    );

    // create info
    MediaItem info = MediaItem(
      path: filepath,
      entityType: entityType,
      modificationDate: lastModified,
      creationDate: creationDate,
      thumbnail: thumbnail,
    );

    // store and return
    _cache[filepath] = info;
    return info;
  }
}

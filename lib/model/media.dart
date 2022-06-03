import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/utils/paths.dart';
import 'package:foto/utils/utils.dart';

class MediaItem {
  final String path;
  final FileSystemEntityType entityType;
  DateTime creationDate;
  DateTime modificationDate;
  final Image? thumbnail;

  static MediaItem forEntity(FileSystemEntity entity) {
    if (entity is File) {
      return MediaItem.forFile(entity.path);
    } else {
      return MediaItem.forFolder(entity.path);
    }
  }

  static MediaItem forFile(String filepath) {
    File file = File(filepath);
    FileStat stats = file.statSync();
    return MediaItem(
      path: filepath,
      entityType: FileSystemEntityType.file,
      creationDate: stats.changed,
      modificationDate: stats.modified,
      thumbnail: Image.file(
        file,
        cacheHeight: 160,
      ),
    );
  }

  static MediaItem forFolder(String folderpath) {
    return MediaItem(
      path: folderpath,
      entityType: FileSystemEntityType.directory,
      modificationDate: DateTime.now(),
      creationDate: DateTime.now(),
      thumbnail: Image.asset(SystemPath.getFolderNamedAsset(folderpath)),
    );
  }

  MediaItem({
    required this.path,
    required this.entityType,
    required this.modificationDate,
    required this.creationDate,
    this.thumbnail,
  });

  String get title {
    return Utils.pathTitle(path)!;
  }

  bool isFile() {
    return entityType == FileSystemEntityType.file;
  }

  bool isDir() {
    return !isFile();
  }

  Key get key {
    return Key('$path-${modificationDate.millisecondsSinceEpoch}');
  }

  void refresh() {
    File file = File(path);
    FileStat stats = file.statSync();
    creationDate = stats.changed;
    modificationDate = stats.modified;
    thumbnail?.image.evict();
  }
}

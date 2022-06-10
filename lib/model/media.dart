import 'dart:io';

import 'package:flutter/material.dart';

import '../browser/thumbnail.dart';
import '../utils/paths.dart';
import '../utils/utils.dart';

class MediaItem {
  final String path;
  final FileSystemEntityType entityType;
  DateTime creationDate;
  DateTime modificationDate;
  SizeInt? imageSize;
  int? fileSize;
  Image? thumbnail;
  final ValueNotifier<int> updateCounter = ValueNotifier<int>(0);

  static MediaItem forEntity(FileSystemEntity entity) {
    if (entity is File) {
      return MediaItem.forFile(entity.path);
    } else {
      return MediaItem.forFolder(entity.path);
    }
  }

  static MediaItem forFile(
    String filepath, {
    DateTime? creationDate,
    DateTime? modificationDate,
  }) {
    File file = File(filepath);
    FileStat stats = file.statSync();
    if (creationDate == null || modificationDate == null) {
      creationDate = creationDate ?? stats.changed;
      modificationDate = modificationDate ?? stats.modified;
    }
    return MediaItem(
      path: filepath,
      entityType: FileSystemEntityType.file,
      fileSize: stats.size,
      creationDate: creationDate,
      modificationDate: modificationDate,
      imageSize: Utils.imageSize(filepath),
      thumbnail: _fileThumbnail(file),
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
    this.fileSize,
    required this.modificationDate,
    required this.creationDate,
    this.imageSize,
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

  void checkForModification() {
    if (isFile()) {
      File file = File(path);
      if (file.existsSync()) {
        FileStat stats = file.statSync();
        if (stats.modified != modificationDate) {
          creationDate = stats.changed;
          modificationDate = stats.modified;
          evictFromCache();
        }
      }
    }
  }

  Future<void> evictFromCache() async {
    if (isFile()) {
      await thumbnail?.image.evict();
      thumbnail = _fileThumbnail(File(path));
      updateCounter.value += 1;
    }
  }

  Future<void> refresh() async {
    File file = File(path);
    FileStat stats = file.statSync();
    creationDate = stats.changed;
    modificationDate = stats.modified;
    evictFromCache();
  }

  static Image _fileThumbnail(File file) {
    return Image.file(
      file,
      cacheHeight: Thumbnail.thumbnailHeight().toInt(),
    );
  }
}

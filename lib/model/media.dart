import 'dart:io';

import 'package:flutter/material.dart';

import '../browser/thumbnail.dart';
import '../utils/file_utils.dart';
import '../utils/image_utils.dart';
import '../utils/paths.dart';
import '../utils/utils.dart';

class MediaItem {
  final String path;
  final FileSystemEntityType entityType;
  bool mediaInfoParsed;
  DateTime creationDate;
  DateTime modificationDate;
  SizeInt? imageSize;
  int? fileSize;
  Image? thumbnail;
  final ValueNotifier<int> updateCounter = ValueNotifier<int>(0);

  static Future<MediaItem> forEntity(FileSystemEntity entity) {
    if (entity is File) {
      return MediaItem.forFile(entity.path);
    } else {
      return MediaItem.forFolder(entity.path);
    }
  }

  static Future<MediaItem> forFile(String filepath) async {
    return MediaItem(
      path: filepath,
      entityType: FileSystemEntityType.file,
      creationDate: await FileUtils.getCreationDate(filepath),
      modificationDate: await FileUtils.getModificationDate(filepath),
      mediaInfoParsed: false,
    );
  }

  static Future<MediaItem> forFolder(String folderpath) async {
    return MediaItem(
      path: folderpath,
      entityType: FileSystemEntityType.directory,
      creationDate: await FileUtils.getCreationDate(folderpath),
      modificationDate: await FileUtils.getModificationDate(folderpath),
      thumbnail: Image.asset(SystemPath.getFolderNamedAsset(folderpath)),
      mediaInfoParsed: true,
    );
  }

  MediaItem({
    required this.path,
    required this.entityType,
    required this.mediaInfoParsed,
    required this.modificationDate,
    required this.creationDate,
    this.fileSize,
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

  Future<void> getMediaInfo() async {
    fileSize = File(path).statSync().size;
    creationDate = await ImageUtils.getCreationDate(path);
    imageSize = Utils.imageSize(path);
    thumbnail = _fileThumbnail(File(path));
    mediaInfoParsed = true;
    evictFromCache();
  }

  static Image _fileThumbnail(File file) {
    return Image.file(
      file,
      cacheHeight: Thumbnail.thumbnailHeight().toInt(),
    );
  }
}

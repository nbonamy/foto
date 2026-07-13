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
  bool captureDateParsed;
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
      captureDateParsed: false,
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
      captureDateParsed: true,
    );
  }

  MediaItem({
    required this.path,
    required this.entityType,
    required this.mediaInfoParsed,
    required this.modificationDate,
    required this.creationDate,
    this.captureDateParsed = false,
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

  Future<bool> checkForModification() async {
    if (!isFile()) return false;

    final stats = await File(path).stat();
    if (stats.type != FileSystemEntityType.file ||
        stats.modified == modificationDate) {
      return false;
    }

    modificationDate = stats.modified;
    _invalidateMediaInfo();
    await evictFromCache();
    return true;
  }

  Future<void> evictFromCache() async {
    if (isFile()) {
      await thumbnail?.image.evict();
      thumbnail = _fileThumbnail(File(path));
      updateCounter.value += 1;
    }
  }

  Future<void> refresh() async {
    final file = File(path);
    final stats = await file.stat();
    modificationDate = stats.modified;
    _invalidateMediaInfo();
    await evictFromCache();
  }

  Future<void> getMediaInfo() async {
    await getCaptureDate();
    fileSize = (await File(path).stat()).size;
    imageSize = Utils.imageSize(path);
    thumbnail = _fileThumbnail(File(path));
    mediaInfoParsed = true;
    updateCounter.value += 1;
  }

  Future<void> getCaptureDate() async {
    if (!isFile() || captureDateParsed) return;
    creationDate = await ImageUtils.getCreationDate(path);
    captureDateParsed = true;
  }

  void _invalidateMediaInfo() {
    captureDateParsed = false;
    mediaInfoParsed = false;
    fileSize = null;
    imageSize = null;
  }

  static Image _fileThumbnail(File file) {
    return Image.file(
      file,
      cacheHeight: Thumbnail.thumbnailHeight().toInt(),
    );
  }
}

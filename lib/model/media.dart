import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import '../utils/file_utils.dart';
import '../utils/image_utils.dart';
import '../utils/paths.dart';
import '../utils/utils.dart';
import 'file_metadata.dart';

class MediaItem {
  final String path;
  final FileSystemEntityType entityType;
  bool mediaInfoParsed;
  bool captureDateParsed;
  DateTime creationDate;
  DateTime modificationDate;
  SizeInt? imageSize;
  double? previewAspectRatio;
  int? fileSize;
  Image? thumbnail;
  final ValueNotifier<int> updateCounter = ValueNotifier<int>(0);
  int _metadataGeneration = 0;

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
      thumbnail: _fileThumbnail(File(filepath)),
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

  static MediaItem forMetadata(FileMetadata metadata) {
    final isFile = metadata.entityType == FileSystemEntityType.file;
    return MediaItem(
      path: metadata.path,
      entityType: metadata.entityType,
      creationDate: metadata.creationDate,
      modificationDate: metadata.modificationDate,
      mediaInfoParsed: !isFile,
      captureDateParsed: !isFile,
      fileSize: isFile ? metadata.size : null,
      thumbnail: isFile
          ? _fileThumbnail(File(metadata.path))
          : Image.asset(SystemPath.getFolderNamedAsset(metadata.path)),
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

  double get aspectRatio {
    final size = imageSize;
    if (size != null && size.width > 0 && size.height > 0) {
      return size.width / size.height;
    }
    final previewRatio = previewAspectRatio;
    if (previewRatio != null && previewRatio.isFinite && previewRatio > 0) {
      return previewRatio;
    }
    if (isDir()) return 1.15;

    // Give unloaded network images stable, varied placeholder geometry. The
    // real ratio replaces this value when the visible thumbnail decodes, so
    // no extra network read is needed merely to lay out the folder.
    final unit = (path.hashCode & 0x3FF) / 0x3FF;
    return 0.82 + unit * 1.08;
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

  Future<void> getMediaInfo({bool loadCaptureDate = true}) async {
    final generation = _metadataGeneration;
    DateTime? loadedCaptureDate;
    if (loadCaptureDate && !captureDateParsed) {
      loadedCaptureDate = await ImageUtils.getCreationDate(path);
    }

    int? loadedFileSize;
    SizeInt? loadedImageSize;
    if (!mediaInfoParsed) {
      loadedFileSize = fileSize ?? (await File(path).stat()).size;
      loadedImageSize = await Isolate.run(() => Utils.imageSize(path));
    }
    if (generation != _metadataGeneration) return;

    var changed = false;
    if (loadedCaptureDate != null) {
      creationDate = loadedCaptureDate;
      captureDateParsed = true;
      changed = true;
    }
    if (loadedImageSize != null) {
      fileSize = loadedFileSize;
      imageSize = loadedImageSize;
      mediaInfoParsed = true;
      thumbnail ??= _fileThumbnail(File(path));
      changed = true;
    }
    if (changed) {
      updateCounter.value += 1;
    }
  }

  Future<void> getCaptureDate() async {
    if (!isFile() || captureDateParsed) return;
    final generation = _metadataGeneration;
    final loadedCreationDate = await ImageUtils.getCreationDate(path);
    if (generation != _metadataGeneration) return;
    creationDate = loadedCreationDate;
    captureDateParsed = true;
  }

  void _invalidateMediaInfo() {
    _metadataGeneration += 1;
    captureDateParsed = false;
    mediaInfoParsed = false;
    fileSize = null;
    imageSize = null;
  }

  static Image _fileThumbnail(File file) {
    return Image.file(
      file,
      cacheHeight: 480,
    );
  }
}

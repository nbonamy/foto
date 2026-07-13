import 'dart:io';

class FileMetadata {
  final String path;
  final FileSystemEntityType entityType;
  final DateTime creationDate;
  final DateTime modificationDate;
  final int? size;

  const FileMetadata({
    required this.path,
    required this.entityType,
    required this.creationDate,
    required this.modificationDate,
    this.size,
  });

  factory FileMetadata.fromPlatformMap(Map<Object?, Object?> map) {
    final path = map['path'];
    final type = map['type'];
    final creationDate = map['creationDate'];
    final modificationDate = map['modificationDate'];
    final size = map['size'];
    if (path is! String ||
        (type != 'file' && type != 'directory') ||
        creationDate is! num ||
        modificationDate is! num ||
        (size != null && size is! num)) {
      throw const FormatException('Invalid directory scan entry.');
    }
    return FileMetadata(
      path: path,
      entityType: type == 'file'
          ? FileSystemEntityType.file
          : FileSystemEntityType.directory,
      creationDate: _dateFromEpochSeconds(creationDate),
      modificationDate: _dateFromEpochSeconds(modificationDate),
      size: type == 'file' ? (size as num?)?.toInt() : null,
    );
  }

  static DateTime _dateFromEpochSeconds(num seconds) {
    return DateTime.fromMicrosecondsSinceEpoch(
      (seconds.toDouble() * Duration.microsecondsPerSecond).round(),
    );
  }
}

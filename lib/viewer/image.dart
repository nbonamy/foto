import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// we need this to force reload on image modification (rotations)
class ImageFile extends FileImage {
  static final Map<String, int> _generations = <String, int>{};

  final int _version;

  ImageFile(String path)
      : _version = Object.hash(
          _generations[path] ?? 0,
          _lastModified(path),
        ),
        super(File(path));

  static int _lastModified(String path) {
    try {
      return File(path).lastModifiedSync().microsecondsSinceEpoch;
    } on FileSystemException {
      return 0;
    }
  }

  /// Ensures the next provider created for [path] has a fresh cache key.
  static void invalidatePath(String path) {
    _generations[path] = (_generations[path] ?? 0) + 1;
  }

  @override
  Future<ImageFile> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<ImageFile>(this);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    } else {
      return other is ImageFile &&
          other.file.path == file.path &&
          other._version == _version;
    }
  }

  @override
  int get hashCode => Object.hash(file.path, _version);
}

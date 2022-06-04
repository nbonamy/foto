import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// we need this to force reload on image modification (rotations)
// ignore: must_be_immutable
class ImageFile extends FileImage {
  int _version;
  ImageFile(String path)
      : _version = 0,
        super(File(path));

  void invalidate() {
    _version += 1;
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

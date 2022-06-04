// we need this to force reload on image modification (rotations)
import 'dart:math';

import 'package:flutter/material.dart';

class ImageFile extends FileImage {
  final double _version;
  ImageFile(super.file) : _version = Random().nextDouble();

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

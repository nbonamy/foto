import 'dart:io';
import 'dart:math';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart' as isg;

class SizeInt {
  final int width;
  final int height;

  SizeInt(this.width, this.height);

  SizeInt get flipped => SizeInt(height, width);

  Size toSize() {
    return Size(width.toDouble(), height.toDouble());
  }
}

class Utils {
  static String? pathTitle(String? path) {
    return (path == null) ? null : ((path == '/') ? '/' : path.split('/').last);
  }

  static SizeInt imageSize(String filepath) {
    isg.Size imageSize = isg.ImageSizeGetter.getSize(FileInput(File(filepath)));
    SizeInt size = SizeInt(imageSize.width, imageSize.height);
    return imageSize.needRotate ? size.flipped : size;
  }

  static double scaleForContained(Size screenSize, Size childSize) {
    final double imageWidth = childSize.width;
    final double imageHeight = childSize.height;

    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    return min(screenWidth / imageWidth, screenHeight / imageHeight);
  }

  static double scaleForCovering(Size screenSize, Size childSize) {
    final double imageWidth = childSize.width;
    final double imageHeight = childSize.height;

    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    return max(screenWidth / imageWidth, screenHeight / imageHeight);
  }

  static String formatExifValue(IfdTag exifTag,
      {bool parseRatio = false, String prefix = '', String suffix = ''}) {
    // get default value
    String value = exifTag.printable;

    // ratios
    if (parseRatio && exifTag.values is IfdRatios) {
      Ratio ratio = exifTag.values.toList()[0];
      double num = ratio.numerator.toDouble() / ratio.denominator.toDouble();
      value = num.toStringAsFixed(1);
    }

    // done
    return '$prefix$value$suffix';
  }
}

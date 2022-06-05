import 'dart:math';

import 'package:flutter/material.dart';

class Utils {
  static String? pathTitle(String? path) {
    return (path == null) ? null : ((path == '/') ? '/' : path.split('/').last);
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
}

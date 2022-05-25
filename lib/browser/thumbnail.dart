import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/utils/paths.dart';
import 'package:foto/utils/utils.dart';

class Thumbnail extends StatelessWidget {
  static const double thumbnailWidth = 160;
  static const double thumbnailPadding = 8;
  static const double highlightRadius = 6;
  static const Color highlightColor = Colors.black;
  static const double labelSpacing = 8;
  static const double labelHeight = 44;
  static const double labelFontSize = 12;

  static double thumbnailHeight() {
    return thumbnailWidth + labelSpacing + labelHeight + thumbnailPadding;
  }

  static double aspectRatio() {
    return thumbnailWidth / Thumbnail.thumbnailHeight();
  }

  final String path;
  final bool folder;
  final bool selected;

  const Thumbnail({
    super.key,
    required this.path,
    required this.folder,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: thumbnailWidth,
      height: Thumbnail.thumbnailHeight(),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              padding: const EdgeInsets.all(thumbnailPadding),
              decoration: BoxDecoration(
                color: selected ? highlightColor : Colors.transparent,
                borderRadius: BorderRadius.circular(highlightRadius),
              ),
              child: folder
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(SystemPath.getFolderNamedAsset(path)),
                    )
                  : Image.file(
                      File(path),
                      cacheWidth: thumbnailWidth.toInt(),
                    ),
            ),
          ),
          Container(
            width: thumbnailWidth,
            height: labelHeight,
            padding: const EdgeInsets.only(top: labelSpacing),
            child: Text(
              Utils.pathTitle(path) ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: labelFontSize,
                color: Colors.white,
              ),
            ),
          )
        ],
      ),
    );
  }
}

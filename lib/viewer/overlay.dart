// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:async';
import 'dart:io';

import 'package:exif/exif.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/utils/utils.dart';
import 'package:intl/intl.dart';

class InfoOverlay extends StatefulWidget {
  final String image;
  final double? scale;

  const InfoOverlay({
    super.key,
    required this.image,
    required this.scale,
  });

  @override
  State<InfoOverlay> createState() => _InfoOverlayState();
}

class _InfoOverlayState extends State<InfoOverlay> {
  int? _fileSize;
  SizeInt? _imageSize;
  Map<String, IfdTag>? _exif;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void didUpdateWidget(covariant InfoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _loadInfo();
    }
  }

  void _loadInfo() {
    final int generation = ++_loadGeneration;
    final String image = widget.image;
    final File file = File(image);

    _fileSize = null;
    _imageSize = null;
    _exif = null;

    try {
      _fileSize = file.lengthSync();
      _imageSize = Utils.imageSize(image);
    } on FileSystemException {
      // The file may have been moved or deleted while the viewer was open.
    } on FormatException {
      // Unsupported or partially-written images simply omit dimensions.
    } catch (_) {
      // Image decoders may throw package-specific errors for invalid files.
    }

    unawaited(_readExif(file, image, generation));
  }

  Future<void> _readExif(File file, String image, int generation) async {
    try {
      final Map<String, IfdTag> value = await readExifFromFile(file);
      if (!mounted || generation != _loadGeneration || image != widget.image) {
        return;
      }
      setState(() => _exif = value);
    } catch (_) {
      // Missing or malformed EXIF data is not an error for the viewer.
    }
  }

  @override
  Widget build(BuildContext context) {
    Preferences prefs = Preferences.of(context);
    TextStyle textStyle = const TextStyle(
      color: Color.fromARGB(255, 92, 202, 71),
      fontFeatures: [
        FontFeature.tabularFigures(),
      ],
    );

    List<Widget> texts = [];
    if (prefs.overlayLevel != OverlayLevel.none) {
      texts.add(
        Text(
          widget.image,
          style: textStyle,
        ),
      );
    }
    if (_imageSize != null) {
      if (prefs.overlayLevel == OverlayLevel.image ||
          prefs.overlayLevel == OverlayLevel.exif) {
        var size = filesize(_fileSize ?? 0);
        texts.add(Text(
          '${_imageSize!.width} x ${_imageSize!.height} pixels${widget.scale != null ? ' (Zoom x${widget.scale?.toStringAsFixed(4)})' : ''}, ${size}',
          style: textStyle,
        ));
      }
      if (prefs.overlayLevel == OverlayLevel.exif && _exif != null) {
        // date time original
        String? datetime = _exif?['EXIF DateTimeOriginal']?.printable;
        if (datetime != null) {
          try {
            DateFormat format = DateFormat('yyyy:MM:dd HH:mm:ss');
            DateTime dt = format.parseStrict(datetime);
            texts.add(Text(DateFormat().format(dt), style: textStyle));
          } on FormatException {
            // Ignore malformed dates while keeping the remaining EXIF fields.
          }
        }

        // picture info
        IfdTag? exposureTime = _exif?['EXIF ExposureTime'];
        IfdTag? fNumber = _exif?['EXIF FNumber'];
        IfdTag? isoSpeedRatings = _exif?['EXIF ISOSpeedRatings'];
        IfdTag? focalLength = _exif?['EXIF FocalLength'];
        String exifInfo = '';
        if (exposureTime != null) {
          exifInfo += Utils.formatExifValue(exposureTime, suffix: ' sec. ');
        }
        if (fNumber != null) {
          exifInfo += Utils.formatExifValue(fNumber,
              parseRatio: true, prefix: 'f/', suffix: ' ');
        }
        if (isoSpeedRatings != null) {
          exifInfo += Utils.formatExifValue(isoSpeedRatings,
              prefix: 'ISO', suffix: ' ');
        }
        if (focalLength != null) {
          exifInfo += Utils.formatExifValue(focalLength,
              parseRatio: true, suffix: 'mm');
        }
        if (exifInfo.trim().isNotEmpty) {
          texts.add(Text(exifInfo.trim(), style: textStyle));
        }
      }
    }

    if (texts.isEmpty) {
      return const SizedBox();
    }

    return Container(
      color: const Color.fromARGB(180, 0, 0, 0),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: texts,
      ),
    );
  }
}

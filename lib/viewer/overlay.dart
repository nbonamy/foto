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
import 'package:provider/provider.dart';

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
    final prefs = context.watch<Preferences>();

    final lines = <String>[];
    if (prefs.overlayLevel != OverlayLevel.none) {
      lines.add(widget.image);
    }
    if (_imageSize != null) {
      if (prefs.overlayLevel == OverlayLevel.image ||
          prefs.overlayLevel == OverlayLevel.exif) {
        var size = filesize(_fileSize ?? 0);
        lines.add(
          '${_imageSize!.width} x ${_imageSize!.height} pixels${widget.scale != null ? ' (Zoom x${widget.scale?.toStringAsFixed(4)})' : ''}, ${size}',
        );
      }
      if (prefs.overlayLevel == OverlayLevel.exif && _exif != null) {
        // date time original
        String? datetime = _exif?['EXIF DateTimeOriginal']?.printable;
        if (datetime != null) {
          try {
            DateFormat format = DateFormat('yyyy:MM:dd HH:mm:ss');
            DateTime dt = format.parseStrict(datetime);
            lines.add(DateFormat().format(dt));
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
          lines.add(exifInfo.trim());
        }
      }
    }

    if (lines.isEmpty) {
      return const SizedBox();
    }

    return ViewerInfoPanel(lines: lines);
  }
}

class ViewerInfoPanel extends StatelessWidget {
  const ViewerInfoPanel({super.key, required this.lines});

  final List<String> lines;

  static const TextStyle textStyle = TextStyle(
    color: Color(0xFFF5F7FA),
    fontFamily: '.AppleSystemUIFont',
    fontFamilyFallback: ['SF Pro Text', 'Helvetica Neue', 'Arial'],
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: 0.05,
    decoration: TextDecoration.none,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12 + safePadding.left,
        12 + safePadding.top,
        12,
        12,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC101217),
            border: Border.all(color: const Color(0x2EFFFFFF)),
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [
              BoxShadow(
                color: Color(0x42000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: DefaultTextStyle(
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < lines.length; index += 1) ...[
                    Text(lines[index]),
                    if (index < lines.length - 1) const SizedBox(height: 2),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

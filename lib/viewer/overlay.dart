// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:io';
import 'package:exif/exif.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:foto/utils/preferences.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:intl/intl.dart';

class InfoOverlay extends StatefulWidget {
  final String image;
  final OverlayLevel level;

  const InfoOverlay({
    super.key,
    required this.image,
    required this.level,
  });

  @override
  State<InfoOverlay> createState() => _InfoOverlayState();
}

class _InfoOverlayState extends State<InfoOverlay> {
  File? _file;
  Size? _size;
  Map<String, IfdTag>? _exif;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void didUpdateWidget(covariant InfoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadInfo();
  }

  void _loadInfo() {
    _file = File(widget.image);
    _size = ImageSizeGetter.getSize(FileInput(_file!));
    readExifFromFile(_file!).then((value) => setState(() {
          _exif = value;
        }));
  }

  @override
  Widget build(BuildContext context) {
    TextStyle textStyle = const TextStyle(
      color: Color.fromARGB(255, 92, 202, 71),
    );

    List<Widget> texts = [];
    if (widget.level != OverlayLevel.none) {
      texts.add(
        Text(
          widget.image,
          style: textStyle,
        ),
      );
    }
    if (_size != null) {
      if (widget.level == OverlayLevel.image ||
          widget.level == OverlayLevel.exif) {
        var width = _size!.width;
        var height = _size!.height;
        var size = filesize(_file?.lengthSync());
        if (_exif?.containsKey('Image Orientation') == true) {
          int? orientation = _exif?['Image Orientation']?.values.firstAsInt();
          if (orientation != null && orientation >= 5 && orientation <= 8) {
            int swap = width;
            width = height;
            height = swap;
          }
        }
        texts.add(Text(
          '${width}x${height} pixels (${size})',
          style: textStyle,
        ));
      }
      if (widget.level == OverlayLevel.exif && _exif != null) {
        // date time original
        String? datetime = _exif?['EXIF DateTimeOriginal']?.printable;
        if (datetime != null) {
          DateFormat format = DateFormat('yyyy:MM:dd HH:mm:ss');
          DateTime dt = format.parse(datetime);
          texts.add(Text(DateFormat().format(dt), style: textStyle));
        }

        // picture info
        String? exposureTime = _exif?['EXIF ExposureTime']?.printable;
        String? fNumber = _exif?['EXIF FNumber']?.printable;
        String? isoSpeedRatings = _exif?['EXIF ISOSpeedRatings']?.printable;
        String? focalLength = _exif?['EXIF FocalLength']?.printable;
        String exifInfo = '';
        if (exposureTime != null) {
          exifInfo += '${exposureTime} sec. ';
        }
        if (fNumber != null) {
          exifInfo += 'f/${_parseRatio(fNumber)} ';
        }
        if (isoSpeedRatings != null) {
          exifInfo += 'ISO${isoSpeedRatings} ';
        }
        if (focalLength != null) {
          exifInfo += '${_parseRatio(focalLength)}mm';
        }
        if (exifInfo.trim().isNotEmpty) {
          texts.add(Text(exifInfo.trim(), style: textStyle));
        }
      }
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

  String? _parseRatio(String? exifValue) {
    if (exifValue == null) return null;
    List<String> values = exifValue.split('/');
    if (values.length != 2) {
      return exifValue;
    }
    try {
      int num = int.parse(values[0]);
      int den = int.parse(values[1]);
      double ratio = num / den;
      return ratio.toStringAsFixed(1);
    } catch (e) {
      return exifValue;
    }
  }
}

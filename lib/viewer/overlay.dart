// ignore_for_file: unnecessary_brace_in_string_interps

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
  File? _file;
  SizeInt? _imageSize;
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
    _imageSize = Utils.imageSize(widget.image);
    readExifFromFile(_file!).then((value) => setState(() {
          _exif = value;
        }));
  }

  @override
  Widget build(BuildContext context) {
    Preferences prefs = Preferences.of(context);
    TextStyle textStyle = const TextStyle(
      color: Color.fromARGB(255, 92, 202, 71),
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
        var size = filesize(_file?.lengthSync());
        texts.add(Text(
          '${_imageSize!.width} x ${_imageSize!.height} pixels${widget.scale != null ? ' (Zoom x${widget.scale?.toStringAsFixed(4)})' : ''}, ${size}',
          style: textStyle,
        ));
      }
      if (prefs.overlayLevel == OverlayLevel.exif && _exif != null) {
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

    if (texts.isEmpty) {
      return Container();
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

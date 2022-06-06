import 'dart:io';
import 'dart:math';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:foto/model/selection.dart';
import 'package:foto/utils/utils.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart' as imsg;
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class InspectorValue {
  final String name;
  final String value;

  InspectorValue(this.name, this.value);
}

extension FileFormatter on num {
  String readableFileSize({bool base1024 = true}) {
    final base = base1024 ? 1024 : 1000;
    if (this <= 0) return '0';
    final units = ['B', 'kB', 'MB', 'GB', 'TB'];
    int digitGroups = (log(this) / log(base)).round();
    return '${NumberFormat('#,##0.#').format(this / pow(base, digitGroups))} ${units[digitGroups]}';
  }
}

class Inspector extends StatefulWidget {
  const Inspector({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _InspectorState();
}

class _InspectorState extends State<Inspector> {
  String? _currentFile;
  FileStat? _fileStats;
  imsg.Size? _imageSize;
  Map<String, IfdTag>? _exifData;

  @override
  void initState() {
    super.initState();
    SelectionModel.of(context).addListener(_onSelectionChange);
    _onSelectionChange();
  }

  @override
  void dispose() {
    SelectionModel.of(context).removeListener(_onSelectionChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // check
    if (_currentFile == null) {
      return Container();
    }

    // needed
    AppLocalizations t = AppLocalizations.of(context)!;

    // rows
    List<InspectorValue> data = [];
    data.add(InspectorValue(t.exifFileName, Utils.pathTitle(_currentFile)!));
    data.add(InspectorValue(
        t.exifFileSize, _fileStats?.size.readableFileSize() ?? ''));
    data.add(InspectorValue(
        t.exifCreationDate, _getExifTag('EXIF DateTimeOriginal')));
    data.add(InspectorValue(
        t.exifImageSize,
        _imageSize == null
            ? ''
            : '${_imageSize?.width} x ${_imageSize?.height}'));
    data.add(
        InspectorValue(t.exifOrientation, _getExifTag('Image Orientation')));
    data.add(InspectorValue(t.exifSceneType, _getExifTag('EXIF SceneType')));
    data.add(InspectorValue(
        t.exifCaptureType, _getExifTag('EXIF SceneCaptureType')));
    data.add(
        InspectorValue(t.exifExposureMode, _getExifTag('EXIF ExposureMode')));
    data.add(InspectorValue(
        t.exifExposureTime, _getExifTag('EXIF ExposureTime', suffix: ' s')));
    data.add(InspectorValue(
        t.exifFNumber, _getExifTag('EXIF FNumber', prefix: 'f')));
    data.add(InspectorValue(
        t.exifFocalLength, _getExifTag('EXIF FocalLength', suffix: ' mm')));
    data.add(
        InspectorValue(t.exifISORating, _getExifTag('EXIF ISOSpeedRatings')));
    data.add(InspectorValue(t.exifExposureBias,
        _getExifTag('EXIF ExposureBiasValue', suffix: ' EV')));
    data.add(InspectorValue(t.exifFlashMode, _getExifTag('EXIF Flash')));
    data.add(
        InspectorValue(t.exifWhiteBalance, _getExifTag('EXIF WhiteBalance')));
    data.add(
        InspectorValue(t.exifBrightness, _getExifTag('EXIF BrightnessValue')));
    data.add(InspectorValue(t.exifContrast, _getExifTag('EXIF Contrast')));
    data.add(InspectorValue(t.exifSaturation, _getExifTag('EXIF Saturation')));
    data.add(InspectorValue(t.exifSharpness, _getExifTag('EXIF Sharpness')));
    data.add(InspectorValue(t.exifCameraMake, _getExifTag('Image Make')));
    data.add(InspectorValue(t.exifCameraModel, _getExifTag('Image Model')));
    data.add(InspectorValue(t.exifColorModel, _getExifTag('EXIF ColorSpace')));
    data.add(InspectorValue(t.exifProfileName, _getExifTag('')));

    // convert to rows
    List<TableRow> rows = [];
    for (var value in data) {
      if (value.value == '') continue;
      rows.add(const TableRow(children: [
        SizedBox(height: 4),
        SizedBox(height: 4),
        SizedBox(height: 4),
      ]));
      rows.add(
        TableRow(
          children: [
            TableCell(
              child: Text(
                value.name,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 2),
            TableCell(
              child: Text(
                value.value,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
      rows.add(const TableRow(children: [
        SizedBox(height: 4),
        SizedBox(height: 4),
        SizedBox(height: 4),
      ]));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FixedColumnWidth(8),
          2: FlexColumnWidth(1.0),
        },
        children: rows,
      ),
    );
  }

  void _onSelectionChange() async {
    Selection selection = SelectionModel.of(context).get;
    if (selection.length != 1) {
      _currentFile = null;
      _exifData = null;
    } else {
      _currentFile = selection[0];
      File file = File(_currentFile!);
      _fileStats = await file.stat();
      _imageSize = imsg.ImageSizeGetter.getSize(FileInput(file));
      _exifData = await readExifFromBytes(file.readAsBytesSync());
    }
    setState(() {});
  }

  String _getExifTag(String tag, {String prefix = '', String suffix = ''}) {
    String? value = _exifData?[tag]?.toString();
    return value == null ? '' : '$prefix$value$suffix';
  }
}

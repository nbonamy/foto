import 'dart:io';

import 'package:exif/exif.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../model/selection.dart';
import '../utils/utils.dart';

class InspectorValue {
  final String name;
  final String value;

  InspectorValue(this.name, this.value);
}

class Inspector extends StatefulWidget {
  const Inspector({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _InspectorState();
}

class _InspectorState extends State<Inspector> {
  String? _currentFile;
  FileStat? _fileStats;
  SizeInt? _imageSize;
  Map<String, IfdTag>? _exifData;
  late SelectionModel _selectionModel;

  @override
  void initState() {
    super.initState();
    _selectionModel = SelectionModel.of(context);
    _selectionModel.addListener(_onSelectionChange);
    _onSelectionChange();
  }

  @override
  void dispose() {
    _selectionModel.removeListener(_onSelectionChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // check
    if (_currentFile == null) {
      return const SizedBox();
    }

    // needed
    AppLocalizations t = AppLocalizations.of(context)!;

    // rows
    List<InspectorValue> data = [];
    data.add(InspectorValue(
      t.exifFileName,
      Utils.pathTitle(_currentFile)!,
    ));
    data.add(InspectorValue(
      t.exifFileSize,
      _fileStats?.size == null ? '' : filesize(_fileStats?.size),
    ));
    data.add(InspectorValue(
      t.exifCreationDate,
      _fileStats?.changed.toString().substring(0, 19) ?? '',
    ));
    data.add(InspectorValue(
      t.exifCaptureDate,
      _getExifTag('EXIF DateTimeOriginal'),
    ));
    data.add(InspectorValue(
      t.exifImageSize,
      _imageSize == null ? '' : '${_imageSize?.width} x ${_imageSize?.height}',
    ));
    data.add(InspectorValue(
      t.exifOrientation,
      _getExifTag('Image Orientation'),
    ));
    data.add(InspectorValue(
      t.exifSceneType,
      _getExifTag('EXIF SceneType'),
    ));
    data.add(InspectorValue(
      t.exifCaptureType,
      _getExifTag('EXIF SceneCaptureType'),
    ));
    data.add(InspectorValue(
      t.exifExposureMode,
      _getExifTag('EXIF ExposureMode'),
    ));
    data.add(InspectorValue(
      t.exifExposureTime,
      _getExifTag('EXIF ExposureTime', suffix: ' s'),
    ));
    data.add(InspectorValue(
      t.exifFNumber,
      _getExifTag('EXIF FNumber', parseRatio: true, prefix: 'f'),
    ));
    data.add(InspectorValue(
      t.exifFocalLength,
      _getExifTag('EXIF FocalLength', parseRatio: true, suffix: ' mm'),
    ));
    data.add(InspectorValue(
      t.exifISORating,
      _getExifTag('EXIF ISOSpeedRatings'),
    ));
    data.add(InspectorValue(
      t.exifExposureBias,
      _getExifTag('EXIF ExposureBiasValue', suffix: ' EV'),
    ));
    data.add(InspectorValue(
      t.exifFlashMode,
      _getExifTag('EXIF Flash'),
    ));
    data.add(InspectorValue(
      t.exifWhiteBalance,
      _getExifTag('EXIF WhiteBalance'),
    ));
    data.add(InspectorValue(
      t.exifBrightness,
      _getExifTag('EXIF BrightnessValue', parseRatio: true),
    ));
    data.add(InspectorValue(
      t.exifContrast,
      _getExifTag('EXIF Contrast'),
    ));
    data.add(InspectorValue(
      t.exifSaturation,
      _getExifTag('EXIF Saturation'),
    ));
    data.add(InspectorValue(
      t.exifSharpness,
      _getExifTag('EXIF Sharpness'),
    ));
    data.add(InspectorValue(
      t.exifCameraMake,
      _getExifTag('Image Make'),
    ));
    data.add(InspectorValue(
      t.exifCameraModel,
      _getExifTag('Image Model'),
    ));
    data.add(InspectorValue(
      t.exifColorModel,
      _getExifTag('EXIF ColorSpace'),
    ));
    data.add(InspectorValue(
      t.exifProfileName,
      _getExifTag(''),
    ));

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
    try {
      Selection selection = SelectionModel.of(context).get;
      if (selection.length != 1) {
        _currentFile = null;
        _exifData = null;
      } else {
        _currentFile = selection[0];
        File file = File(_currentFile!);
        _fileStats = await file.stat();
        _imageSize = Utils.imageSize(_currentFile!);
        _exifData = await readExifFromBytes(file.readAsBytesSync());
      }
    } catch (_) {
      _currentFile = null;
    }
    setState(() {});
  }

  String _getExifTag(String tag,
      {bool parseRatio = false, String prefix = '', String suffix = ''}) {
    IfdTag? exifTag = _exifData?[tag];
    if (exifTag == null) {
      return '';
    }

    // default
    return Utils.formatExifValue(
      exifTag,
      parseRatio: parseRatio,
      prefix: prefix,
      suffix: suffix,
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:exif/exif.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:foto/l10n/app_localizations.dart';

import '../components/theme.dart';
import '../model/selection.dart';
import '../utils/file_utils.dart';
import '../utils/utils.dart';

class InspectorValue {
  final String name;
  final String value;

  InspectorValue(this.name, this.value);
}

class InspectorGroup {
  const InspectorGroup(this.title, this.values);

  final String title;
  final List<InspectorValue> values;
}

class _InspectorFileMetadata {
  final SizeInt imageSize;
  final Map<String, IfdTag> exifData;

  const _InspectorFileMetadata(this.imageSize, this.exifData);
}

class Inspector extends StatefulWidget {
  const Inspector({super.key});

  @override
  State<StatefulWidget> createState() => _InspectorState();
}

class _InspectorState extends State<Inspector> {
  String? _currentFile;
  FileStat? _fileStats;
  DateTime? _creationDate;
  SizeInt? _imageSize;
  Map<String, IfdTag>? _exifData;
  bool _isLoading = false;
  late SelectionModel _selectionModel;
  int _loadGeneration = 0;
  Timer? _loadDebounce;

  @override
  void initState() {
    super.initState();
    _selectionModel = SelectionModel.of(context);
    _selectionModel.addListener(_onSelectionChange);
    _onSelectionChange();
  }

  @override
  void dispose() {
    _loadDebounce?.cancel();
    _selectionModel.removeListener(_onSelectionChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return InspectorPanel(
      title: t.inspectorTitle,
      emptyMessage: t.inspectorEmpty,
      loadingLabel: t.inspectorLoading,
      loading: _isLoading,
      groups: _currentFile == null ? const [] : _buildGroups(t),
    );
  }

  List<InspectorGroup> _buildGroups(AppLocalizations t) {
    return [
      InspectorGroup(t.inspectorFileSection, [
        InspectorValue(t.exifFileName, Utils.pathTitle(_currentFile) ?? ''),
        InspectorValue(
          t.exifFileSize,
          _fileStats?.size == null ? '' : filesize(_fileStats?.size),
        ),
        InspectorValue(
          t.exifCreationDate,
          _creationDate?.toString().substring(0, 19) ?? '',
        ),
        InspectorValue(
          t.exifImageSize,
          _imageSize == null
              ? ''
              : '${_imageSize?.width} × ${_imageSize?.height}',
        ),
      ]),
      InspectorGroup(t.inspectorCaptureSection, [
        InspectorValue(t.exifCaptureDate, _getExifTag('EXIF DateTimeOriginal')),
        InspectorValue(
          t.exifExposureTime,
          _getExifTag('EXIF ExposureTime', suffix: ' s'),
        ),
        InspectorValue(
          t.exifFNumber,
          _getExifTag('EXIF FNumber', parseRatio: true, prefix: 'f'),
        ),
        InspectorValue(t.exifISORating, _getExifTag('EXIF ISOSpeedRatings')),
        InspectorValue(
          t.exifExposureBias,
          _getExifTag('EXIF ExposureBiasValue', suffix: ' EV'),
        ),
        InspectorValue(t.exifFlashMode, _getExifTag('EXIF Flash')),
        InspectorValue(t.exifWhiteBalance, _getExifTag('EXIF WhiteBalance')),
      ]),
      InspectorGroup(t.inspectorCameraSection, [
        InspectorValue(t.exifCameraMake, _getExifTag('Image Make')),
        InspectorValue(t.exifCameraModel, _getExifTag('Image Model')),
        InspectorValue(
          t.exifFocalLength,
          _getExifTag('EXIF FocalLength', parseRatio: true, suffix: ' mm'),
        ),
      ]),
      InspectorGroup(t.inspectorImageSection, [
        InspectorValue(t.exifOrientation, _getExifTag('Image Orientation')),
        InspectorValue(t.exifSceneType, _getExifTag('EXIF SceneType')),
        InspectorValue(
          t.exifCaptureType,
          _getExifTag('EXIF SceneCaptureType'),
        ),
        InspectorValue(t.exifExposureMode, _getExifTag('EXIF ExposureMode')),
        InspectorValue(
          t.exifBrightness,
          _getExifTag('EXIF BrightnessValue', parseRatio: true),
        ),
        InspectorValue(t.exifContrast, _getExifTag('EXIF Contrast')),
        InspectorValue(t.exifSaturation, _getExifTag('EXIF Saturation')),
        InspectorValue(t.exifSharpness, _getExifTag('EXIF Sharpness')),
        InspectorValue(t.exifColorModel, _getExifTag('EXIF ColorSpace')),
      ]),
    ];
  }

  void _onSelectionChange() {
    final int generation = ++_loadGeneration;
    _loadDebounce?.cancel();
    final Selection selection = SelectionModel.of(context).get;

    if (selection.length != 1) {
      if (mounted) {
        setState(_clearSelection);
      }
      return;
    }

    final String filePath = selection.single;
    if (mounted) {
      setState(() {
        _currentFile = filePath;
        _fileStats = null;
        _creationDate = null;
        _imageSize = null;
        _exifData = null;
        _isLoading = true;
      });
    }

    _loadDebounce = Timer(const Duration(milliseconds: 50), () {
      unawaited(_loadMetadata(filePath, generation));
    });
  }

  Future<void> _loadMetadata(String filePath, int generation) async {
    try {
      final File file = File(filePath);
      final fileStatsFuture = file.stat();
      final creationDateFuture = FileUtils.getCreationDate(filePath);
      final metadataFuture = Isolate.run(() async {
        Map<String, IfdTag> exifData = const {};
        try {
          exifData = await readExifFromFile(File(filePath));
        } catch (_) {
          // Formats such as WebP may have no EXIF block. Their basic file and
          // image metadata should still remain visible in the inspector.
        }
        return _InspectorFileMetadata(Utils.imageSize(filePath), exifData);
      });
      final fileStats = await fileStatsFuture;
      final creationDate = await creationDateFuture;
      final metadata = await metadataFuture;

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _currentFile = filePath;
        _fileStats = fileStats;
        _creationDate = creationDate;
        _imageSize = metadata.imageSize;
        _exifData = metadata.exifData;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(_clearSelection);
    }
  }

  void _clearSelection() {
    _currentFile = null;
    _fileStats = null;
    _creationDate = null;
    _imageSize = null;
    _exifData = null;
    _isLoading = false;
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

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    super.key,
    required this.title,
    required this.emptyMessage,
    required this.loadingLabel,
    required this.groups,
    this.loading = false,
  });

  final String title;
  final String emptyMessage;
  final String loadingLabel;
  final List<InspectorGroup> groups;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final visibleGroups = groups
        .map(
          (group) => InspectorGroup(
            group.title,
            group.values.where((value) => value.value.isNotEmpty).toList(),
          ),
        )
        .where((group) => group.values.isNotEmpty)
        .toList(growable: false);

    return ColoredBox(
      color: palette.sidebarSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
          Divider(color: palette.divider),
          if (groups.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_outlined,
                        color: palette.secondaryText,
                        size: 30,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: palette.secondaryText,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                children: [
                  if (loading) ...[
                    LinearProgressIndicator(
                      minHeight: 2,
                      color: palette.accent,
                      backgroundColor: palette.selectionFill,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loadingLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: palette.secondaryText,
                          ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (var index = 0;
                      index < visibleGroups.length;
                      index += 1) ...[
                    _InspectorGroupCard(group: visibleGroups[index]),
                    if (index < visibleGroups.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InspectorGroupCard extends StatelessWidget {
  const _InspectorGroupCard({required this.group});

  final InspectorGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(
            group.title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.secondaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.7,
                ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.elevatedSurface,
            border: Border.all(color: palette.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Column(
              children: [
                for (var index = 0; index < group.values.length; index += 1)
                  _InspectorRow(
                    value: group.values[index],
                    showDivider: index < group.values.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InspectorRow extends StatelessWidget {
  const _InspectorRow({required this.value, required this.showDivider});

  final InspectorValue value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: palette.divider))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                value.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.secondaryText,
                      fontSize: 11,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Text(
                value.value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.primaryText,
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

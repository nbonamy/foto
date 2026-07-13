import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../components/theme.dart';
import '../model/selection.dart';
import '../utils/file_utils.dart';
import '../utils/platform_utils.dart';
import '../utils/utils.dart';
import 'photo_metadata.dart';

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

class InspectorFact {
  const InspectorFact(this.value);

  final String value;
}

class InspectorSummary {
  const InspectorSummary({
    required this.filename,
    required this.dateLabel,
    required this.date,
    required this.details,
    required this.facts,
  });

  final String filename;
  final String dateLabel;
  final DateTime? date;
  final String details;
  final List<InspectorFact> facts;
}

typedef InspectorMapSnapshotLoader = Future<Uint8List?> Function(
  PhotoLocation location,
  bool dark,
  double scale,
);

Future<Uint8List?> loadInspectorMapSnapshot(
  PhotoLocation location,
  bool dark,
  double scale,
) {
  return PlatformUtils.renderMapSnapshot(
    latitude: location.latitude,
    longitude: location.longitude,
    dark: dark,
    scale: scale,
  );
}

class InspectorMetadata {
  const InspectorMetadata({
    required this.fileSize,
    required this.creationDate,
    required this.imageSize,
    required this.exifData,
  });

  final int fileSize;
  final DateTime creationDate;
  final SizeInt? imageSize;
  final Map<String, IfdTag> exifData;
}

typedef InspectorMetadataLoader = Future<InspectorMetadata> Function(
  String filePath,
);

Future<InspectorMetadata> loadInspectorMetadata(String filePath) async {
  final file = File(filePath);
  final fileStatsFuture = file.stat();
  final creationDateFuture = _loadCreationDate(filePath);
  final imageSizeFuture = Isolate.run<List<int>?>(() {
    try {
      final size = Utils.imageSize(filePath);
      return [size.width, size.height];
    } catch (_) {
      return null;
    }
  });
  final exifFuture = () async {
    Map<String, IfdTag> exifData = const {};
    try {
      exifData = await readExifFromFile(file);
    } catch (_) {
      // Basic file metadata remains useful for formats without EXIF.
    }
    return exifData;
  }();
  final fileStats = await fileStatsFuture;
  final imageDimensions = await imageSizeFuture;
  return InspectorMetadata(
    fileSize: fileStats.size,
    creationDate: await creationDateFuture ?? fileStats.changed,
    imageSize: imageDimensions == null
        ? null
        : SizeInt(imageDimensions[0], imageDimensions[1]),
    exifData: await exifFuture,
  );
}

Future<DateTime?> _loadCreationDate(String filePath) async {
  try {
    return await FileUtils.getCreationDate(filePath);
  } catch (_) {
    return null;
  }
}

class Inspector extends StatefulWidget {
  const Inspector({
    super.key,
    this.metadataLoader = loadInspectorMetadata,
  });

  final InspectorMetadataLoader metadataLoader;

  @override
  State<StatefulWidget> createState() => _InspectorState();
}

class _InspectorState extends State<Inspector> {
  String? _currentFile;
  int? _fileSize;
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
      summary: _currentFile == null ? null : _buildSummary(t),
      location: photoLocationFromExif(_exifData ?? const {}),
      technicalDetailsLabel: t.inspectorTechnicalDetails,
      noLocationLabel: t.inspectorNoLocation,
      mapUnavailableLabel: t.inspectorMapUnavailable,
      groups: _currentFile == null ? const [] : _buildGroups(t),
    );
  }

  InspectorSummary _buildSummary(AppLocalizations t) {
    final captureDate = captureDateFromExif(_exifData ?? const {});
    final details = <String>[
      if (_imageSize != null) '${_imageSize!.width} × ${_imageSize!.height}',
      if (_fileSize != null) filesize(_fileSize),
      p.extension(_currentFile!).replaceFirst('.', '').toUpperCase(),
    ].where((value) => value.isNotEmpty).join('  •  ');
    final facts = <InspectorFact>[
      InspectorFact(_getExifTag('EXIF ISOSpeedRatings', prefix: 'ISO ')),
      InspectorFact(
        _getExifTag('EXIF FocalLength', parseRatio: true, suffix: ' mm'),
      ),
      InspectorFact(
        _getExifTag('EXIF FNumber', parseRatio: true, prefix: 'f/'),
      ),
      InspectorFact(_getExifTag('EXIF ExposureTime', suffix: ' s')),
    ].where((fact) => fact.value.isNotEmpty).toList(growable: false);
    return InspectorSummary(
      filename: Utils.pathTitle(_currentFile) ?? '',
      dateLabel: captureDate == null ? t.inspectorCreated : t.inspectorCaptured,
      date: captureDate ?? _creationDate,
      details: details,
      facts: facts,
    );
  }

  List<InspectorGroup> _buildGroups(AppLocalizations t) {
    return [
      InspectorGroup(t.inspectorFileSection, [
        InspectorValue(t.exifFileName, Utils.pathTitle(_currentFile) ?? ''),
        InspectorValue(
          t.exifFileSize,
          _fileSize == null ? '' : filesize(_fileSize),
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
        _fileSize = null;
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
      final metadata = await widget.metadataLoader(filePath);

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _currentFile = filePath;
        _fileSize = metadata.fileSize;
        _creationDate = metadata.creationDate;
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
    _fileSize = null;
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
    this.summary,
    this.location,
    this.technicalDetailsLabel = 'Technical details',
    this.noLocationLabel = 'No location saved for this photo.',
    this.mapUnavailableLabel = 'Map unavailable',
    this.mapSnapshotLoader = loadInspectorMapSnapshot,
    this.loading = false,
  });

  final String title;
  final String emptyMessage;
  final String loadingLabel;
  final List<InspectorGroup> groups;
  final InspectorSummary? summary;
  final PhotoLocation? location;
  final String technicalDetailsLabel;
  final String noLocationLabel;
  final String mapUnavailableLabel;
  final InspectorMapSnapshotLoader mapSnapshotLoader;
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
          if (summary == null && groups.isEmpty)
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
                  if (summary != null) ...[
                    _InspectorSummaryCard(summary: summary!),
                    const SizedBox(height: 12),
                    if (!loading) ...[
                      _InspectorMapCard(
                        location: location,
                        noLocationLabel: noLocationLabel,
                        mapUnavailableLabel: mapUnavailableLabel,
                        snapshotLoader: mapSnapshotLoader,
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                  if (visibleGroups.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        technicalDetailsLabel.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: palette.secondaryText,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                      ),
                    ),
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

class _InspectorSummaryCard extends StatelessWidget {
  const _InspectorSummaryCard({required this.summary});

  final InspectorSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formattedDate = summary.date == null
        ? null
        : DateFormat.yMMMd(locale).add_jms().format(summary.date!);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.dateLabel.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.secondaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              formattedDate ?? summary.filename,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
            ),
            if (formattedDate != null) ...[
              const SizedBox(height: 5),
              Text(
                summary.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.secondaryText,
                    ),
              ),
            ],
            if (summary.details.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                summary.details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.secondaryText,
                      height: 1.25,
                    ),
              ),
            ],
            if (summary.facts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final fact in summary.facts)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.selectionFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Text(
                          fact.value,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: palette.primaryText,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InspectorMapCard extends StatefulWidget {
  const _InspectorMapCard({
    required this.location,
    required this.noLocationLabel,
    required this.mapUnavailableLabel,
    required this.snapshotLoader,
  });

  final PhotoLocation? location;
  final String noLocationLabel;
  final String mapUnavailableLabel;
  final InspectorMapSnapshotLoader snapshotLoader;

  @override
  State<_InspectorMapCard> createState() => _InspectorMapCardState();
}

class _InspectorMapCardState extends State<_InspectorMapCard> {
  Uint8List? _snapshot;
  bool _loading = false;
  int _loadGeneration = 0;
  String? _requestKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _InspectorMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.snapshotLoader != widget.snapshotLoader) {
      _requestKey = null;
      _loadIfNeeded();
    }
  }

  void _loadIfNeeded() {
    final location = widget.location;
    if (location == null) {
      _snapshot = null;
      _loading = false;
      _requestKey = null;
      return;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scale = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final key = '${location.latitude}:${location.longitude}:$dark:$scale';
    if (_requestKey == key) return;
    _requestKey = key;
    _snapshot = null;
    _loading = true;
    final generation = ++_loadGeneration;
    widget.snapshotLoader(location, dark, scale).then((snapshot) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    }).catchError((_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _snapshot = null;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final location = widget.location;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (location == null) {
      return _MapFallback(
        icon: Icons.location_off_outlined,
        label: widget.noLocationLabel,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_snapshot != null) ...[
              CustomPaint(painter: _MapBackdropPainter(dark: dark)),
              Image.memory(
                _snapshot!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ] else
              ColoredBox(
                color: palette.elevatedSurface,
                child: _loading
                    ? Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.accent,
                          ),
                        ),
                      )
                    : _MapFallback(
                        icon: Icons.map_outlined,
                        label: widget.mapUnavailableLabel,
                        compact: true,
                      ),
              ),
            if (_snapshot != null) ...[
              const Center(
                child: Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF5D5FEF),
                  size: 34,
                  shadows: [
                    Shadow(color: Color(0x80000000), blurRadius: 8),
                  ],
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              left: 10,
              bottom: 8,
              child: Text(
                '${location.latitude.toStringAsFixed(4)}, '
                '${location.longitude.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _snapshot == null
                          ? palette.secondaryText
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: _snapshot == null
                          ? null
                          : const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBackdropPainter extends CustomPainter {
  const _MapBackdropPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final water = Paint()
      ..color = dark ? const Color(0xFF1B3444) : const Color(0xFFAED8EA);
    final land = Paint()
      ..color = dark ? const Color(0xFF355044) : const Color(0xFFC9DFB3);
    final road = Paint()
      ..color = dark ? const Color(0xFF8B785F) : const Color(0xFFF0C979)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, water);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.2)
        ..cubicTo(
          size.width * 0.28,
          size.height * 0.06,
          size.width * 0.52,
          size.height * 0.42,
          size.width,
          size.height * 0.12,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      land,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-10, size.height * 0.78)
        ..cubicTo(
          size.width * 0.3,
          size.height * 0.56,
          size.width * 0.62,
          size.height * 0.74,
          size.width + 10,
          size.height * 0.34,
        ),
      road,
    );
  }

  @override
  bool shouldRepaint(_MapBackdropPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return Container(
      height: compact ? null : 92,
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 23, color: palette.secondaryText),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.secondaryText,
                    ),
              ),
            ],
          ),
        ),
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

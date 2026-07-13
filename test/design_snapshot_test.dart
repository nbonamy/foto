import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/inspector.dart';
import 'package:foto/browser/justified_gallery_view.dart';
import 'package:foto/browser/justified_layout.dart';
import 'package:foto/browser/photo_metadata.dart';
import 'package:foto/components/theme.dart';
import 'package:foto/components/toolbar.dart';
import 'package:foto/components/window_shell.dart';

final Uint8List _previewMapBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fontBytes =
        await File('/System/Library/Fonts/SFNS.ttf').readAsBytes();
    final loader = FontLoader('FotoScreenshotFont')
      ..addFont(Future.value(ByteData.sublistView(fontBytes)));
    await loader.load();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await iconLoader.load();
  });

  for (final brightness in Brightness.values) {
    testWidgets('foto ${brightness.name} design snapshot', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_DesignPreview(brightness: brightness));
      await tester.pump();
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_DesignPreview),
        matchesGoldenFile('goldens/foto-${brightness.name}.png'),
      );
    });
  }
}

class _DesignPreview extends StatelessWidget {
  const _DesignPreview({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final baseTheme =
        brightness == Brightness.light ? FotoTheme.light : FotoTheme.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(fontFamily: 'FotoScreenshotFont'),
        primaryTextTheme:
            baseTheme.primaryTextTheme.apply(fontFamily: 'FotoScreenshotFont'),
      ),
      home: const Scaffold(
        body: FotoWindowShell(
          showSidebar: true,
          sidebar: _PreviewSidebar(),
          child: Column(
            children: [
              FotoToolbar(
                title: 'Summer in Japan',
                leading: FotoToolbarButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Back',
                  onPressed: _noop,
                ),
                actions: [
                  FotoToolbarButton(
                    icon: Icons.folder_open_outlined,
                    tooltip: 'Open folder',
                    onPressed: _noop,
                  ),
                  FotoToolbarButton(
                    icon: Icons.swap_vert_rounded,
                    tooltip: 'Sort',
                    onPressed: _noop,
                  ),
                  FotoToolbarButton(
                    icon: Icons.info_outline_rounded,
                    tooltip: 'Inspector',
                    onPressed: _noop,
                    selected: true,
                  ),
                ],
              ),
              Expanded(
                child: FotoSplitView(
                  trailing: _PreviewInspector(),
                  child: _PreviewGallery(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _noop() {}

class _PreviewSidebar extends StatelessWidget {
  const _PreviewSidebar();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      children: const [
        _SidebarLabel('FAVORITES'),
        _SidebarItem(Icons.photo_library_outlined, 'Photos', selected: true),
        _SidebarItem(Icons.schedule_rounded, 'Recent'),
        _SidebarItem(Icons.favorite_border_rounded, 'Favorites'),
        SizedBox(height: 20),
        _SidebarLabel('LOCATIONS'),
        _SidebarItem(Icons.laptop_mac_rounded, 'Macintosh HD'),
        _SidebarItem(Icons.cloud_outlined, 'Photo Archive'),
        _SidebarItem(Icons.storage_rounded, 'Studio NAS'),
      ],
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 7),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.secondaryText,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(this.icon, this.label, {this.selected = false});

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? palette.selectionFill : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: selected ? palette.accent : palette.secondaryText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.primaryText,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewGallery extends StatelessWidget {
  const _PreviewGallery();

  static const ratios = [
    1.52,
    0.72,
    1.15,
    1.88,
    0.82,
    1.34,
    1.0,
    1.72,
    0.68,
    1.26,
    1.95,
    0.9,
    1.46,
    0.76,
    1.62,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = JustifiedGalleryLayout.compute(
          aspectRatios: ratios,
          availableWidth: constraints.maxWidth - 32,
          targetRowHeight: 168,
        );
        return JustifiedGalleryView(
          layout: layout,
          itemBuilder: (context, index) => _PhotoTile(
            index: index,
            selected: index == 5,
          ),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.index, required this.selected});

  final int index;
  final bool selected;

  static const gradients = [
    [Color(0xFF3F718D), Color(0xFFE0B987)],
    [Color(0xFF6F7966), Color(0xFFD5C49A)],
    [Color(0xFF965E51), Color(0xFFDBB77C)],
    [Color(0xFF263A50), Color(0xFF91A8A3)],
    [Color(0xFF826E8E), Color(0xFFE0AD9C)],
    [Color(0xFF355A47), Color(0xFFB7A46B)],
    [Color(0xFF8C5844), Color(0xFFE4C9A6)],
    [Color(0xFF4A6173), Color(0xFFB8D1C3)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = gradients[index % gradients.length];
    final palette = FotoPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: selected ? Border.all(color: palette.accent, width: 3) : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(selected ? 7 : 10),
        child: CustomPaint(painter: _PhotoPainter(index)),
      ),
    );
  }
}

class _PhotoPainter extends CustomPainter {
  const _PhotoPainter(this.index);

  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()..color = const Color(0x33000000);
    final highlight = Paint()..color = const Color(0x59FFFFFF);
    canvas.drawCircle(
      Offset(size.width * (0.25 + (index % 3) * 0.18), size.height * 0.32),
      size.shortestSide * 0.12,
      highlight,
    );
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.35, size.height * 0.52)
      ..lineTo(size.width * 0.58, size.height * 0.78)
      ..lineTo(size.width * 0.78, size.height * 0.46)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, shadow);
  }

  @override
  bool shouldRepaint(_PhotoPainter oldDelegate) => oldDelegate.index != index;
}

class _PreviewInspector extends StatelessWidget {
  const _PreviewInspector();

  @override
  Widget build(BuildContext context) {
    return InspectorPanel(
      title: 'Info',
      emptyMessage: '',
      loadingLabel: '',
      loading: false,
      summary: InspectorSummary(
        dateLabel: 'Captured',
        date: DateTime(2026, 7, 12, 18, 42),
      ),
      location: const PhotoLocation(
        latitude: 64.1466,
        longitude: -21.9426,
      ),
      noLocationLabel: 'No location saved for this photo.',
      mapUnavailableLabel: 'Map unavailable',
      mapSnapshotLoader: _previewMapSnapshot,
      groups: [
        InspectorGroup('File', [
          InspectorValue('Name', 'DSC_4821.jpg'),
          InspectorValue('Size', '8.4 MB'),
          InspectorValue('Created', 'Jul 12, 2026  18:42'),
          InspectorValue('Dimensions', '6000 × 4000'),
        ]),
        InspectorGroup('Capture', [
          InspectorValue('Exposure', '1/250 s'),
          InspectorValue('Aperture', 'f/2.8'),
          InspectorValue('ISO', '200'),
        ]),
        InspectorGroup('Camera', [
          InspectorValue('Model', 'Leica Q3'),
          InspectorValue('Focal length', '28 mm'),
        ]),
      ],
    );
  }
}

Future<Uint8List?> _previewMapSnapshot(
  PhotoLocation location,
  bool dark,
  double scale,
  double distanceMeters,
) {
  return Future.value(_previewMapBytes);
}

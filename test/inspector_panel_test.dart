import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/inspector.dart';
import 'package:foto/browser/photo_metadata.dart';
import 'package:foto/components/theme.dart';

void main() {
  Widget harness(Widget child, ThemeData theme, {double height = 600}) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SizedBox(width: 320, height: height, child: child),
      ),
    );
  }

  testWidgets('inspector presents grouped metadata and omits empty values',
      (tester) async {
    await tester.pumpWidget(
      harness(
        InspectorPanel(
          title: 'Info',
          emptyMessage: 'Select a photo',
          loadingLabel: 'Loading metadata',
          groups: [
            InspectorGroup('File', [
              InspectorValue('Filename', 'sunrise.jpg'),
              InspectorValue('Empty', ''),
            ]),
            InspectorGroup('Camera', [
              InspectorValue('Model', 'Leica Q3'),
            ]),
          ],
        ),
        FotoTheme.dark,
      ),
    );

    expect(find.text('Info'), findsOneWidget);
    expect(find.text('FILE'), findsOneWidget);
    expect(find.text('CAMERA'), findsOneWidget);
    expect(find.text('sunrise.jpg'), findsOneWidget);
    expect(find.text('Leica Q3'), findsOneWidget);
    expect(find.text('Empty'), findsNothing);
  });

  testWidgets('inspector has a useful empty state', (tester) async {
    await tester.pumpWidget(
      harness(
        const InspectorPanel(
          title: 'Info',
          emptyMessage: 'Select a photo',
          loadingLabel: 'Loading metadata',
          groups: [],
        ),
        FotoTheme.light,
      ),
    );

    expect(find.text('Select a photo'), findsOneWidget);
    expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
  });

  testWidgets('loading state remains visible above available file data',
      (tester) async {
    await tester.pumpWidget(
      harness(
        InspectorPanel(
          title: 'Info',
          emptyMessage: 'Select a photo',
          loadingLabel: 'Loading metadata',
          loading: true,
          groups: [
            InspectorGroup('File', [
              InspectorValue('Filename', 'sunrise.jpg'),
            ]),
          ],
        ),
        FotoTheme.light,
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Loading metadata'), findsOneWidget);
    expect(find.text('sunrise.jpg'), findsOneWidget);
  });

  testWidgets('capture card precedes metadata sections', (tester) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    final requestedLocations = <PhotoLocation>[];
    final requestedDistances = <double>[];
    await tester.pumpWidget(
      harness(
        InspectorPanel(
          title: 'Info',
          emptyMessage: 'Select a photo',
          loadingLabel: 'Loading metadata',
          noLocationLabel: 'No location',
          mapUnavailableLabel: 'Map unavailable',
          summary: InspectorSummary(
            dateLabel: 'Captured',
            date: DateTime(2024, 5, 12, 16, 32, 18),
          ),
          location: const PhotoLocation(
            latitude: 64.1466,
            longitude: -21.9426,
          ),
          mapSnapshotLoader: (location, dark, scale, distanceMeters) async {
            requestedLocations.add(location);
            requestedDistances.add(distanceMeters);
            return base64Decode(png);
          },
          groups: [
            InspectorGroup('Camera', [
              InspectorValue('Model', 'Canon EOS R6'),
            ]),
          ],
        ),
        FotoTheme.light,
        height: 360,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CAPTURED'), findsOneWidget);
    expect(find.textContaining('May 12, 2024'), findsOneWidget);
    expect(find.text('iceland.jpg'), findsNothing);
    expect(find.text('ISO 100'), findsNothing);
    expect(find.text('4032 × 5040  •  20.3 MB  •  JPEG'), findsNothing);
    expect(find.text('64.1466, -21.9426'), findsOneWidget);
    expect(find.text('TECHNICAL DETAILS'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(requestedLocations.single.latitude, 64.1466);
    expect(requestedDistances, [60000]);
    expect(
      tester.getTopLeft(find.text('CAPTURED')).dy,
      lessThan(tester.getTopLeft(find.text('CAMERA')).dy),
    );

    final inspectorScrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(InspectorPanel),
        matching: find.byType(Scrollable),
      ),
    );
    expect(inspectorScrollable.position.pixels, 0);

    final mapCenter = tester.getCenter(
      find.byKey(const ValueKey('inspector-map-surface')),
    );
    final trackpad = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await trackpad.panZoomStart(mapCenter);
    await trackpad.panZoomUpdate(
      mapCenter,
      pan: const Offset(0, -20),
    );
    await tester.pump();

    final zoomTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('inspector-map-zoom-transform')),
    );
    expect(zoomTransform.transform.getMaxScaleOnAxis(), greaterThan(1));
    expect(requestedLocations, hasLength(1));

    await trackpad.panZoomUpdate(
      mapCenter,
      pan: const Offset(0, -100),
    );
    await tester.pump();

    final deepZoomTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('inspector-map-zoom-transform')),
    );
    expect(deepZoomTransform.transform.getMaxScaleOnAxis(), greaterThan(1.55));
    expect(requestedLocations, hasLength(1));

    await trackpad.panZoomEnd();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(requestedLocations, hasLength(2));
    expect(requestedLocations[1], requestedLocations[0]);
    expect(requestedDistances.first, 60000);
    expect(requestedDistances.last, inExclusiveRange(30000, 40000));
    expect(inspectorScrollable.position.pixels, 0);
  });
}

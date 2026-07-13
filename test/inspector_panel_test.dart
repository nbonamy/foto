import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/inspector.dart';
import 'package:foto/browser/photo_metadata.dart';
import 'package:foto/components/theme.dart';

void main() {
  Widget harness(Widget child, ThemeData theme) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(body: SizedBox(width: 320, height: 600, child: child)),
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

  testWidgets('capture context and map precede technical details',
      (tester) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    PhotoLocation? requestedLocation;
    await tester.pumpWidget(
      harness(
        InspectorPanel(
          title: 'Info',
          emptyMessage: 'Select a photo',
          loadingLabel: 'Loading metadata',
          technicalDetailsLabel: 'Technical details',
          noLocationLabel: 'No location',
          mapUnavailableLabel: 'Map unavailable',
          summary: InspectorSummary(
            filename: 'iceland.jpg',
            dateLabel: 'Captured',
            date: DateTime(2024, 5, 12, 16, 32, 18),
            details: '4032 × 5040  •  20.3 MB  •  JPEG',
            facts: const [
              InspectorFact('ISO 100'),
              InspectorFact('50 mm'),
              InspectorFact('f/2.0'),
              InspectorFact('1/640 s'),
            ],
          ),
          location: const PhotoLocation(
            latitude: 64.1466,
            longitude: -21.9426,
          ),
          mapSnapshotLoader: (location, dark, scale) async {
            requestedLocation = location;
            return base64Decode(png);
          },
          groups: [
            InspectorGroup('Camera', [
              InspectorValue('Model', 'Canon EOS R6'),
            ]),
          ],
        ),
        FotoTheme.light,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CAPTURED'), findsOneWidget);
    expect(find.textContaining('May 12, 2024'), findsOneWidget);
    expect(find.text('ISO 100'), findsOneWidget);
    expect(find.text('64.1466, -21.9426'), findsOneWidget);
    expect(find.text('TECHNICAL DETAILS'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(requestedLocation?.latitude, 64.1466);
    expect(
      tester.getTopLeft(find.text('CAPTURED')).dy,
      lessThan(tester.getTopLeft(find.text('TECHNICAL DETAILS')).dy),
    );
  });
}

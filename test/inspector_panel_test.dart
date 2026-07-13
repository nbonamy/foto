import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/inspector.dart';
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
}

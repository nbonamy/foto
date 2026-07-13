import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/gallery_status_view.dart';
import 'package:foto/components/theme.dart';

void main() {
  testWidgets('gallery loading state stays lightweight and informative',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FotoTheme.light,
        home: const GalleryStatusView(
          message: 'Loading photos…',
          loading: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading photos…'), findsOneWidget);
  });

  testWidgets('gallery empty state works in dark appearance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FotoTheme.dark,
        home: const GalleryStatusView(message: 'No photos in this folder.'),
      ),
    );

    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.text('No photos in this folder.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

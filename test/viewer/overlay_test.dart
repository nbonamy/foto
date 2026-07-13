import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/viewer/overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final bytes = await File('/System/Library/Fonts/SFNS.ttf').readAsBytes();
    final loader = FontLoader('.AppleSystemUIFont')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  testWidgets('fullscreen info uses explicit system typography and truncates',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(
          color: Colors.black,
          child: Align(
            alignment: Alignment.topLeft,
            child: ViewerInfoPanel(
              lines: [
                '/Volumes/Photo Archive/a-very-long-folder-name/another-long-folder-name/DSC_4821.jpg',
                '6000 x 4000 pixels (Zoom x0.1842), 8.4 MB',
              ],
            ),
          ),
        ),
      ),
    );

    final defaultStyle = tester.widget<DefaultTextStyle>(
      find.descendant(
        of: find.byType(ViewerInfoPanel),
        matching: find.byType(DefaultTextStyle),
      ),
    );
    expect(defaultStyle.style.fontFamily, '.AppleSystemUIFont');
    expect(defaultStyle.style.fontFamilyFallback, contains('Helvetica Neue'));
    expect(defaultStyle.style.fontSize, 13);
    expect(defaultStyle.style.height, 1.35);
    expect(defaultStyle.style.decoration, TextDecoration.none);
    expect(defaultStyle.maxLines, 1);
    expect(defaultStyle.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fullscreen info reacts immediately to its preference',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'viewer.overlayLevel': OverlayLevel.file.index,
    });
    final preferences = Preferences();
    await preferences.init();
    const image = '/missing/selected-image.jpg';

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: preferences,
        child: const MaterialApp(
          home: ColoredBox(
            color: Colors.black,
            child: Align(
              alignment: Alignment.topLeft,
              child: InfoOverlay(image: image, scale: null),
            ),
          ),
        ),
      ),
    );

    expect(find.text(image), findsOneWidget);
    preferences.overlayLevel = OverlayLevel.none;
    await tester.pump();
    expect(find.text(image), findsNothing);

    await tester.pumpWidget(const SizedBox());
    preferences.dispose();
  });

  testWidgets('fullscreen info visual', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 560);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF17252E), Color(0xFF8C6A4B)],
            ),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: ViewerInfoPanel(
              lines: [
                '/Volumes/Photo Archive/Summer in Japan/DSC_4821.jpg',
                '6000 x 4000 pixels (Zoom x0.1842), 8.4 MB',
                'Jul 12, 2026, 6:42:18 PM',
                '1/250 sec.  f/2.8  ISO200  28mm',
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(ViewerInfoPanel),
      matchesGoldenFile('goldens/viewer-info-overlay.png'),
    );
  });
}

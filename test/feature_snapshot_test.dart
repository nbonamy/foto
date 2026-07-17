import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/similar_photo_review.dart';
import 'package:foto/browser/similarity_session.dart';
import 'package:foto/compare/compare_view.dart';
import 'package:foto/components/theme.dart';
import 'package:foto/l10n/app_localizations.dart';

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
    testWidgets('similar review ${brightness.name} snapshot', (tester) async {
      _configureSurface(tester);
      final paths = _imagePaths;
      final source = _item(paths.first);
      final session = FolderSimilaritySession(
        folderPath: File(paths.first).parent.path,
        source: source,
        candidates: paths.skip(1).map(_item),
        distanceLoader: (_, candidate) async {
          return candidate.path.endsWith('default.png') ? 3.0 : 10.0;
        },
      );
      addTearDown(session.dispose);

      await tester.pumpWidget(_harness(
        brightness,
        SimilarPhotoReview(
          session: session,
          onClose: () {},
          onCompare: (_) {},
          imageProviderBuilder: _memoryImage,
        ),
      ));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(SimilarPhotoReview),
        matchesGoldenFile(
          'goldens/similar-review-${brightness.name}.png',
        ),
      );
    });

    testWidgets('compare ${brightness.name} snapshot', (tester) async {
      _configureSurface(tester);

      await tester.pumpWidget(_harness(
        brightness,
        CompareView(
          images: _imagePaths.take(4).toList(),
          close: () {},
          imageProviderBuilder: (path) => _memoryImage(_item(path)),
        ),
      ));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(CompareView),
        matchesGoldenFile('goldens/compare-${brightness.name}.png'),
      );
    });
  }
}

const _imagePaths = [
  'assets/img/folders/pictures.png',
  'assets/img/folders/default.png',
  'assets/img/folders/downloads.png',
  'assets/img/folders/documents.png',
  'assets/img/folders/movies.png',
  'assets/img/folders/music.png',
  'assets/img/folders/desktop.png',
  'assets/img/folders/applications.png',
];

SimilarityItem _item(String path) {
  final stat = File(path).statSync();
  return SimilarityItem(
    path: File(path).absolute.path,
    modificationDate: stat.modified,
    fileSize: stat.size,
  );
}

ImageProvider<Object> _memoryImage(SimilarityItem item) {
  return MemoryImage(File(item.path).readAsBytesSync());
}

void _configureSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1180, 760);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });
}

Widget _harness(Brightness brightness, Widget child) {
  final baseTheme =
      brightness == Brightness.light ? FotoTheme.light : FotoTheme.dark;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'FotoScreenshotFont'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'FotoScreenshotFont'),
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

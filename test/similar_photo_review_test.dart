import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/similar_photo_review.dart';
import 'package:foto/browser/similarity_session.dart';
import 'package:foto/components/theme.dart';
import 'package:foto/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late SimilarityItem source;
  late List<SimilarityItem> candidates;

  setUp(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    directory = await Directory.systemTemp.createTemp('foto-similar-review-');
    final bytes = await File('assets/img/foto.png').readAsBytes();
    Future<SimilarityItem> create(String name) async {
      final file = await File('${directory.path}/$name').writeAsBytes(bytes);
      final stat = await file.stat();
      return SimilarityItem(
        path: file.path,
        modificationDate: stat.modified,
        fileSize: stat.size,
      );
    }

    source = await create('source.png');
    candidates = [
      await create('near.png'),
      await create('similar.png'),
      await create('third.png'),
      await create('fourth.png'),
    ];
  });

  tearDown(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await directory.delete(recursive: true);
  });

  Widget harness({
    required FolderSimilaritySession session,
    ValueChanged<List<String>>? onCompare,
  }) {
    return MaterialApp(
      theme: FotoTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SimilarPhotoReview(
          session: session,
          onClose: () {},
          onCompare: onCompare ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('review ranks candidates and compares up to four photos',
      (tester) async {
    final distances = <String, double>{
      candidates[0].path: 2,
      candidates[1].path: 8,
      candidates[2].path: 9,
      candidates[3].path: 10,
    };
    final session = FolderSimilaritySession(
      folderPath: directory.path,
      source: source,
      candidates: candidates,
      distanceLoader: (_, candidate) async => distances[candidate.path]!,
    );
    addTearDown(session.dispose);
    List<String>? compared;

    await tester.pumpWidget(
      harness(session: session, onCompare: (paths) => compared = paths),
    );
    await tester.pumpAndSettle();

    expect(find.text('Near duplicate'), findsOneWidget);
    expect(find.text('Similar'), findsNWidgets(3));
    expect(find.text('1 of 4 selected'), findsOneWidget);

    for (final candidate in candidates) {
      await tester.tap(
        find.byKey(ValueKey('similarity-result-${candidate.path}')),
      );
      await tester.pump();
    }

    expect(find.text('4 of 4 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('compare-similar-photos')));

    expect(compared,
        [source.path, ...candidates.take(3).map((item) => item.path)]);
  });

  testWidgets('analysis can be cancelled without accepting late work',
      (tester) async {
    final pending = <Completer<double>>[];
    final session = FolderSimilaritySession(
      folderPath: directory.path,
      source: source,
      candidates: candidates,
      distanceLoader: (_, __) {
        final completer = Completer<double>();
        pending.add(completer);
        return completer.future;
      },
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(harness(session: session));
    await tester.pump();
    expect(find.byKey(const ValueKey('similarity-progress')), findsOneWidget);

    await tester.tap(find.text('Cancel Analysis'));
    await tester.pump();

    expect(session.status, SimilaritySessionStatus.cancelled);
    expect(find.text('Analysis cancelled.'), findsOneWidget);
    expect(find.text('Analyze Again'), findsOneWidget);
    for (final completer in pending) {
      completer.complete(2);
    }
    await tester.pump();
  });

  testWidgets('completed empty scans explain the folder boundary',
      (tester) async {
    final session = FolderSimilaritySession(
      folderPath: directory.path,
      source: source,
      candidates: const [],
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(harness(session: session));
    await tester.pumpAndSettle();

    expect(
      find.text('No similar photos found in this folder.'),
      findsOneWidget,
    );
    expect(find.text('Results from this folder only'), findsOneWidget);
  });
}

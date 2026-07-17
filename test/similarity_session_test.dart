import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/similarity_session.dart';

void main() {
  SimilarityItem item(String path, {int size = 100}) {
    return SimilarityItem(
      path: path,
      modificationDate: DateTime(2026, 7, 17),
      fileSize: size,
    );
  }

  test('session is strictly limited to the open folder snapshot', () async {
    final compared = <String>[];
    final session = FolderSimilaritySession(
      folderPath: '/photos/current',
      source: item('/photos/current/source.jpg'),
      candidates: [
        item('/photos/current/source.jpg'),
        item('/photos/current/a.jpg'),
        item('/photos/current/a.jpg'),
        item('/photos/other/outside.jpg'),
        item('/photos/current/nested/child.jpg'),
      ],
      distanceLoader: (source, candidate) async {
        compared.add(candidate.path);
        return 2;
      },
    );
    addTearDown(session.dispose);

    await session.start();

    expect(compared, ['/photos/current/a.jpg']);
    expect(session.totalCount, 1);
    expect(session.processedCount, 1);
    expect(session.status, SimilaritySessionStatus.completed);
  });

  test('session rejects a source outside the open folder', () {
    expect(
      () => FolderSimilaritySession(
        folderPath: '/photos/current',
        source: item('/photos/other/source.jpg'),
        candidates: const [],
      ),
      throwsArgumentError,
    );
  });

  test('distance work never exceeds the configured concurrency', () async {
    var active = 0;
    var maximumActive = 0;
    final session = FolderSimilaritySession(
      folderPath: '/photos',
      source: item('/photos/source.jpg'),
      candidates: List.generate(8, (index) => item('/photos/$index.jpg')),
      distanceLoader: (source, candidate) async {
        active += 1;
        if (active > maximumActive) maximumActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 4));
        active -= 1;
        return 8;
      },
    );
    addTearDown(session.dispose);

    await session.start();

    expect(maximumActive, 2);
    expect(session.processedCount, 8);
  });

  test('cancellation stops scheduling and drops late results', () async {
    final started = <String>[];
    final pending = <Completer<double>>[];
    final session = FolderSimilaritySession(
      folderPath: '/photos',
      source: item('/photos/source.jpg'),
      candidates: List.generate(6, (index) => item('/photos/$index.jpg')),
      distanceLoader: (source, candidate) {
        started.add(candidate.path);
        final completer = Completer<double>();
        pending.add(completer);
        return completer.future;
      },
    );
    addTearDown(session.dispose);

    final run = session.start();
    await Future<void>.delayed(Duration.zero);
    expect(started, hasLength(2));

    session.cancel();
    for (final completer in pending) {
      completer.complete(1);
    }
    await run;

    expect(started, hasLength(2));
    expect(session.matches, isEmpty);
    expect(session.processedCount, 0);
    expect(session.status, SimilaritySessionStatus.cancelled);
  });

  test('matches are classified sorted and limited by policy', () async {
    final distances = <String, double>{
      '/photos/a.jpg': 14,
      '/photos/b.jpg': 2,
      '/photos/c.jpg': 7,
      '/photos/d.jpg': 20,
    };
    final session = FolderSimilaritySession(
      folderPath: '/photos',
      source: item('/photos/source.jpg'),
      candidates: distances.keys.map(item),
      policy: const SimilarityRankingPolicy(resultLimit: 2),
      distanceLoader: (source, candidate) async => distances[candidate.path]!,
    );
    addTearDown(session.dispose);

    await session.start();

    expect(session.matches.map((match) => match.item.path), [
      '/photos/b.jpg',
      '/photos/c.jpg',
    ]);
    expect(session.matches.first.band, SimilarityBand.nearDuplicate);
    expect(session.matches.last.band, SimilarityBand.similar);
    expect(session.progress, 1);
  });

  test('a restarted session ignores results from its previous generation',
      () async {
    final firstResult = Completer<double>();
    var calls = 0;
    final session = FolderSimilaritySession(
      folderPath: '/photos',
      source: item('/photos/source.jpg'),
      candidates: [item('/photos/candidate.jpg')],
      distanceLoader: (source, candidate) {
        calls += 1;
        return calls == 1 ? firstResult.future : Future.value(3);
      },
    );
    addTearDown(session.dispose);

    final firstRun = session.start();
    await Future<void>.delayed(Duration.zero);
    final secondRun = session.start();
    await secondRun;
    firstResult.complete(1);
    await firstRun;

    expect(calls, 2);
    expect(session.matches, hasLength(1));
    expect(session.matches.single.distance, 3);
    expect(session.status, SimilaritySessionStatus.completed);
  });

  test('all failed comparisons produce a failed session', () async {
    final session = FolderSimilaritySession(
      folderPath: '/photos',
      source: item('/photos/source.jpg'),
      candidates: [item('/photos/a.jpg'), item('/photos/b.jpg')],
      distanceLoader: (source, candidate) =>
          Future<double>.error(StateError('unreadable')),
    );
    addTearDown(session.dispose);

    await session.start();

    expect(session.failedCount, 2);
    expect(session.lastError, isA<StateError>());
    expect(session.status, SimilaritySessionStatus.failed);
  });
}

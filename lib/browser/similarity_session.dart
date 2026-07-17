import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../utils/platform_utils.dart';

@immutable
class SimilarityItem {
  const SimilarityItem({
    required this.path,
    required this.modificationDate,
    required this.fileSize,
  });

  final String path;
  final DateTime modificationDate;
  final int? fileSize;
}

enum SimilarityBand {
  nearDuplicate,
  similar,
}

@immutable
class SimilarityMatch {
  const SimilarityMatch({
    required this.item,
    required this.distance,
    required this.band,
  });

  final SimilarityItem item;
  final double distance;
  final SimilarityBand band;
}

@immutable
class SimilarityRankingPolicy {
  const SimilarityRankingPolicy({
    this.nearDuplicateMaximum = 5,
    this.similarMaximum = 15,
    this.resultLimit = 40,
  })  : assert(nearDuplicateMaximum >= 0),
        assert(similarMaximum >= nearDuplicateMaximum),
        assert(resultLimit > 0);

  final double nearDuplicateMaximum;
  final double similarMaximum;
  final int resultLimit;

  SimilarityBand? classify(double distance) {
    if (!distance.isFinite || distance < 0 || distance > similarMaximum) {
      return null;
    }
    return distance <= nearDuplicateMaximum
        ? SimilarityBand.nearDuplicate
        : SimilarityBand.similar;
  }

  List<SimilarityMatch> rank(Iterable<SimilarityMatch> matches) {
    final ranked = matches.toList()
      ..sort((left, right) => left.distance.compareTo(right.distance));
    return List.unmodifiable(ranked.take(resultLimit));
  }
}

enum SimilaritySessionStatus {
  idle,
  running,
  completed,
  cancelled,
  failed,
}

typedef VisualDistanceLoader = Future<double> Function(
  SimilarityItem source,
  SimilarityItem candidate,
);

class FolderSimilaritySession extends ChangeNotifier {
  FolderSimilaritySession({
    required String folderPath,
    required this.source,
    required Iterable<SimilarityItem> candidates,
    VisualDistanceLoader? distanceLoader,
    this.policy = const SimilarityRankingPolicy(),
    this.maximumConcurrentOperations = 2,
  })  : assert(maximumConcurrentOperations > 0),
        folderPath = p.normalize(p.absolute(folderPath)),
        _distanceLoader = distanceLoader ?? _loadDistance,
        _candidates = _folderCandidates(
          folderPath,
          source,
          candidates,
        );

  final String folderPath;
  final SimilarityItem source;
  final SimilarityRankingPolicy policy;
  final int maximumConcurrentOperations;
  final VisualDistanceLoader _distanceLoader;
  final List<SimilarityItem> _candidates;

  SimilaritySessionStatus _status = SimilaritySessionStatus.idle;
  SimilaritySessionStatus get status => _status;

  List<SimilarityMatch> _matches = const [];
  List<SimilarityMatch> get matches => _matches;

  int _processedCount = 0;
  int get processedCount => _processedCount;
  int get totalCount => _candidates.length;

  int _failedCount = 0;
  int get failedCount => _failedCount;

  Object? _lastError;
  Object? get lastError => _lastError;

  int _generation = 0;
  bool _disposed = false;

  double get progress => totalCount == 0 ? 1 : processedCount / totalCount;

  Future<void> start() async {
    final generation = ++_generation;
    _status = SimilaritySessionStatus.running;
    _processedCount = 0;
    _failedCount = 0;
    _lastError = null;
    _matches = const [];
    _notify();

    if (_candidates.isEmpty) {
      _complete(generation);
      return;
    }

    var nextIndex = 0;
    final collected = <SimilarityMatch>[];
    Future<void> worker() async {
      while (_isCurrent(generation)) {
        if (nextIndex >= _candidates.length) return;
        final candidate = _candidates[nextIndex];
        nextIndex += 1;
        try {
          final distance = await _distanceLoader(source, candidate);
          if (!_isCurrent(generation)) return;
          final band = policy.classify(distance);
          if (band != null) {
            collected.add(SimilarityMatch(
              item: candidate,
              distance: distance,
              band: band,
            ));
            _matches = policy.rank(collected);
          }
        } catch (error) {
          if (!_isCurrent(generation)) return;
          _failedCount += 1;
          _lastError = error;
        }
        if (!_isCurrent(generation)) return;
        _processedCount += 1;
        _notify();
      }
    }

    final workerCount = min(
      maximumConcurrentOperations,
      _candidates.length,
    );
    await Future.wait(List.generate(workerCount, (_) => worker()));
    _complete(generation);
  }

  void cancel() {
    if (_status != SimilaritySessionStatus.running) return;
    _generation += 1;
    _status = SimilaritySessionStatus.cancelled;
    _notify();
  }

  void _complete(int generation) {
    if (!_isCurrent(generation)) return;
    _status = _failedCount == totalCount && totalCount > 0
        ? SimilaritySessionStatus.failed
        : SimilaritySessionStatus.completed;
    _notify();
  }

  bool _isCurrent(int generation) {
    return !_disposed &&
        generation == _generation &&
        _status == SimilaritySessionStatus.running;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    super.dispose();
  }

  static Future<double> _loadDistance(
    SimilarityItem source,
    SimilarityItem candidate,
  ) {
    return PlatformUtils.compareVisualSimilarity(
      sourcePath: source.path,
      sourceModificationDate: source.modificationDate,
      sourceFileSize: source.fileSize,
      candidatePath: candidate.path,
      candidateModificationDate: candidate.modificationDate,
      candidateFileSize: candidate.fileSize,
    );
  }

  static List<SimilarityItem> _folderCandidates(
    String folderPath,
    SimilarityItem source,
    Iterable<SimilarityItem> candidates,
  ) {
    final normalizedFolder = p.normalize(p.absolute(folderPath));
    final normalizedSource = p.normalize(p.absolute(source.path));
    if (p.dirname(normalizedSource) != normalizedFolder) {
      throw ArgumentError.value(
        source.path,
        'source',
        'The similarity source must belong to the open folder.',
      );
    }

    final seen = <String>{normalizedSource};
    final result = <SimilarityItem>[];
    for (final candidate in candidates) {
      final normalizedPath = p.normalize(p.absolute(candidate.path));
      if (p.dirname(normalizedPath) != normalizedFolder ||
          !seen.add(normalizedPath)) {
        continue;
      }
      result.add(candidate);
    }
    return List.unmodifiable(result);
  }
}

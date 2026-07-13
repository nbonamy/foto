import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foto/model/media.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/utils/media_utils.dart';

MediaItem item(
  String path, {
  required DateTime created,
  FileSystemEntityType type = FileSystemEntityType.file,
}) {
  return MediaItem(
    path: path,
    entityType: type,
    mediaInfoParsed: true,
    modificationDate: created,
    creationDate: created,
  );
}

void main() {
  group('image detection', () {
    test('includes WebP regardless of extension case', () {
      expect(MediaUtils.isImage('/photos/ellie.webp'), isTrue);
      expect(MediaUtils.isImage('/photos/joel.WEBP'), isTrue);
    });

    test('does not accept a filename that only contains webp', () {
      expect(MediaUtils.isImage('/photos/webp-notes.txt'), isFalse);
    });
  });

  group('path ancestry', () {
    test('matches the root itself and actual descendants', () {
      expect(MediaUtils.isPathAtOrBelow('/foo', '/foo'), isTrue);
      expect(MediaUtils.isPathAtOrBelow('/foo/bar', '/foo'), isTrue);
    });

    test('does not confuse sibling path prefixes', () {
      expect(MediaUtils.isPathAtOrBelow('/foobar', '/foo'), isFalse);
      expect(MediaUtils.isPathAtOrBelow('/foobar/image.jpg', '/foo'), isFalse);
    });

    test('chooses the deepest matching root', () {
      expect(
        MediaUtils.deepestContainingRoot(
          '/photos/trips/2026/image.jpg',
          ['/', '/photos', '/photos/trips'],
        ),
        '/photos/trips',
      );
    });
  });

  group('media sorting', () {
    final earlier = DateTime(2025);
    final later = DateTime(2026);

    test('keeps folders first and applies a deterministic date tie-breaker',
        () {
      final items = [
        item('/z.jpg', created: earlier),
        item('/a.jpg', created: earlier),
        item('/folder', created: later, type: FileSystemEntityType.directory),
      ];

      MediaUtils.sortMediaItems(
        items,
        sortCriteria: SortCriteria.chronological,
        sortReversed: false,
      );

      expect(items.map((entry) => entry.path), ['/folder', '/a.jpg', '/z.jpg']);
    });

    test('reverses files without moving folders below them', () {
      final items = [
        item('/a.jpg', created: earlier),
        item('/z.jpg', created: later),
        item('/folder', created: later, type: FileSystemEntityType.directory),
      ];

      MediaUtils.sortMediaItems(
        items,
        sortCriteria: SortCriteria.chronological,
        sortReversed: true,
      );

      expect(items.map((entry) => entry.path), ['/folder', '/z.jpg', '/a.jpg']);
    });
  });

  test('file modification invalidates cached media metadata', () async {
    final directory = await Directory.systemTemp.createTemp('foto-media-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.jpg');
    await file.writeAsBytes([1, 2, 3]);
    final modified = (await file.stat()).modified;
    final media = MediaItem(
      path: file.path,
      entityType: FileSystemEntityType.file,
      mediaInfoParsed: true,
      captureDateParsed: true,
      modificationDate: modified.subtract(const Duration(seconds: 1)),
      creationDate: modified,
      fileSize: 3,
    );

    expect(await media.checkForModification(), isTrue);

    expect(media.modificationDate, modified);
    expect(media.mediaInfoParsed, isFalse);
    expect(media.captureDateParsed, isFalse);
    expect(media.fileSize, isNull);
    expect(await media.checkForModification(), isFalse);
  });
}

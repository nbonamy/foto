import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/model/file_metadata.dart';
import 'package:foto/model/media.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/utils/database.dart';
import 'package:foto/utils/file_utils.dart';
import 'package:foto/utils/media_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fileChannel = MethodChannel('foto_file_utils/messages');
  const imageChannel = MethodChannel('foto_image_utils/messages');

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(fileChannel, null);
    messenger.setMockMethodCallHandler(imageChannel, null);
  });

  test('native directory scans decode all prefetched metadata', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
      expect(call.method, 'scanDirectory');
      expect(call.arguments, '/network/photos');
      return <Object?>[
        <Object?, Object?>{
          'path': '/network/photos/image.webp',
          'type': 'file',
          'creationDate': 1.25,
          'modificationDate': 2.5,
          'size': 42,
        },
        <Object?, Object?>{
          'path': '/network/photos/folder',
          'type': 'directory',
          'creationDate': 3.0,
          'modificationDate': 4.0,
          'size': 0,
        },
      ];
    });

    final entries = await FileUtils.scanDirectory('/network/photos');

    expect(entries, hasLength(2));
    expect(entries.first.entityType, FileSystemEntityType.file);
    expect(entries.first.size, 42);
    expect(entries.first.creationDate.microsecondsSinceEpoch, 1250000);
    expect(entries.last.entityType, FileSystemEntityType.directory);
    expect(entries.last.size, isNull);
    expect(entries.last.modificationDate.microsecondsSinceEpoch, 4000000);
  });

  test('gallery listing returns before capture-date extraction', () async {
    var imageCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(fileChannel, (_) async {
      return <Object?>[
        <Object?, Object?>{
          'path': '/network/photos/later.jpg',
          'type': 'file',
          'creationDate': 20.0,
          'modificationDate': 20.0,
          'size': 200,
        },
        <Object?, Object?>{
          'path': '/network/photos/earlier.webp',
          'type': 'file',
          'creationDate': 10.0,
          'modificationDate': 10.0,
          'size': 100,
        },
      ];
    });
    messenger.setMockMethodCallHandler(imageChannel, (_) async {
      imageCalls += 1;
      return 0.0;
    });

    final items = await MediaUtils.getMediaFiles(
      MediaDb(),
      '/network/photos',
      includeDirs: true,
      sortCriteria: SortCriteria.chronological,
    );

    expect(items.map((item) => item.path), [
      '/network/photos/earlier.webp',
      '/network/photos/later.jpg',
    ]);
    expect(items.every((item) => item.thumbnail != null), isTrue);
    expect(items.every((item) => !item.captureDateParsed), isTrue);
    expect(imageCalls, 0);
  });

  test('large network listings do not trigger per-image metadata reads',
      () async {
    const itemCount = 10000;
    var imageCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(fileChannel, (_) async {
      return List<Object?>.generate(
        itemCount,
        (index) => <Object?, Object?>{
          'path': '/network/photos/image-$index.jpg',
          'type': 'file',
          'creationDate': index.toDouble(),
          'modificationDate': index.toDouble(),
          'size': 100,
        },
      );
    });
    messenger.setMockMethodCallHandler(imageChannel, (_) async {
      imageCalls += 1;
      return 0.0;
    });

    final items = await MediaUtils.getMediaFiles(
      MediaDb(),
      '/network/photos',
      includeDirs: false,
      sortCriteria: SortCriteria.chronological,
    );

    expect(items, hasLength(itemCount));
    expect(items.every((item) => !item.captureDateParsed), isTrue);
    expect(items.every((item) => !item.mediaInfoParsed), isTrue);
    expect(imageCalls, 0);
  });

  test('unchanged scan entries reuse parsed in-memory metadata', () {
    final metadata = FileMetadata(
      path: '/network/photos/image.jpg',
      entityType: FileSystemEntityType.file,
      creationDate: DateTime(2020),
      modificationDate: DateTime(2026),
      size: 123,
    );
    final database = MediaDb();
    final first = database.getScanned(metadata)
      ..creationDate = DateTime(2024)
      ..captureDateParsed = true;

    final second = database.getScanned(metadata);

    expect(second, same(first));
    expect(second.creationDate, DateTime(2024));
    expect(second.captureDateParsed, isTrue);
  });

  test('scan cache invalidates when size or modification date changes', () {
    final database = MediaDb();
    final original = database.getScanned(
      FileMetadata(
        path: '/network/photos/image.jpg',
        entityType: FileSystemEntityType.file,
        creationDate: DateTime(2020),
        modificationDate: DateTime(2026),
        size: 123,
      ),
    );
    final resized = database.getScanned(
      FileMetadata(
        path: original.path,
        entityType: FileSystemEntityType.file,
        creationDate: original.creationDate,
        modificationDate: original.modificationDate,
        size: 456,
      ),
    );
    final modified = database.getScanned(
      FileMetadata(
        path: original.path,
        entityType: FileSystemEntityType.file,
        creationDate: original.creationDate,
        modificationDate: DateTime(2026, 1, 2),
        size: 456,
      ),
    );

    expect(resized, isNot(same(original)));
    expect(modified, isNot(same(resized)));
  });

  test('scanned listings retain image and directory filtering', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (_) async {
      return <Object?>[
        _entry('/network/photos/.hidden.jpg', 'file'),
        _entry(r'/network/photos/$RECYCLE.BIN', 'directory'),
        _entry('/network/photos/notes.txt', 'file'),
        _entry('/network/photos/image.webp', 'file'),
        _entry('/network/photos/album', 'directory'),
      ];
    });

    final filesOnly = await MediaUtils.getMediaFiles(
      null,
      '/network/photos',
      includeDirs: false,
      sortCriteria: SortCriteria.alphabetical,
    );
    final withFolders = await MediaUtils.getMediaFiles(
      null,
      '/network/photos',
      includeDirs: true,
      sortCriteria: SortCriteria.alphabetical,
    );

    expect(filesOnly.map((item) => item.path), [
      '/network/photos/image.webp',
    ]);
    expect(withFolders.map((item) => item.path), [
      '/network/photos/album',
      '/network/photos/image.webp',
    ]);
  });

  test('basic image metadata can load without an EXIF network call', () async {
    const webp =
        'UklGRjIAAABXRUJQVlA4TCUAAAAvAYAAAC8gEEjaH3qN+RcQFPk/2vwHH0QCg0AgDVFkMMAR/Y8GAA==';
    final directory = await Directory.systemTemp.createTemp('foto-scan-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.webp');
    final bytes = base64Decode(webp);
    await file.writeAsBytes(bytes);
    var imageCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imageChannel, (_) async {
      imageCalls += 1;
      return 0.0;
    });
    final stat = await file.stat();
    final media = MediaItem.forMetadata(
      FileMetadata(
        path: file.path,
        entityType: FileSystemEntityType.file,
        creationDate: stat.changed,
        modificationDate: stat.modified,
        size: stat.size,
      ),
    );

    await media.getMediaInfo(loadCaptureDate: false);

    expect(media.mediaInfoParsed, isTrue);
    expect(media.captureDateParsed, isFalse);
    expect(media.imageSize?.width, 2);
    expect(media.imageSize?.height, 3);
    expect(imageCalls, 0);
  });
}

Map<Object?, Object?> _entry(String path, String type) {
  return <Object?, Object?>{
    'path': path,
    'type': type,
    'creationDate': 1.0,
    'modificationDate': 1.0,
    if (type == 'file') 'size': 100,
  };
}

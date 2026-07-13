import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foto/utils/file_utils.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('foto-file-operations-');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<File> createFile(String relativePath, String contents) async {
    final file = File(p.join(root.path, relativePath));
    await file.parent.create(recursive: true);
    return file.writeAsString(contents);
  }

  test('rejects different sources with the same basename before moving',
      () async {
    final first = await createFile('first/image.jpg', 'first');
    final second = await createFile('second/image.jpg', 'second');
    final destination = await Directory(p.join(root.path, 'destination'))
        .create(recursive: true);

    await expectLater(
      FileUtils.copyOrMove(
        [first.path, second.path],
        destination.path,
        move: true,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          contains('same name'),
        ),
      ),
    );

    expect(await first.readAsString(), 'first');
    expect(await second.readAsString(), 'second');
    expect(await File(p.join(destination.path, 'image.jpg')).exists(), isFalse);
  });

  test('copies directories recursively without deleting the source', () async {
    final sourceFile = await createFile('album/nested/image.jpg', 'photo');
    final source = sourceFile.parent.parent;
    final destination = await Directory(p.join(root.path, 'destination'))
        .create(recursive: true);

    await FileUtils.copyOrMove(
      [source.path],
      destination.path,
      move: false,
    );

    expect(await sourceFile.exists(), isTrue);
    expect(
      await File(p.join(destination.path, 'album/nested/image.jpg'))
          .readAsString(),
      'photo',
    );
  });

  test('moves files and directories only after all copies succeed', () async {
    final sourceFile = await createFile('loose.jpg', 'loose');
    final nestedFile = await createFile('album/nested.jpg', 'nested');
    final sourceDirectory = nestedFile.parent;
    final destination = await Directory(p.join(root.path, 'destination'))
        .create(recursive: true);

    await FileUtils.copyOrMove(
      [sourceFile.path, sourceDirectory.path],
      destination.path,
      move: true,
    );

    expect(await sourceFile.exists(), isFalse);
    expect(await sourceDirectory.exists(), isFalse);
    expect(
      await File(p.join(destination.path, 'loose.jpg')).readAsString(),
      'loose',
    );
    expect(
      await File(p.join(destination.path, 'album/nested.jpg')).readAsString(),
      'nested',
    );
  });

  test('detects directory collisions and replaces them only when requested',
      () async {
    final sourceFile = await createFile('source/album/new.jpg', 'new');
    final sourceDirectory = sourceFile.parent;
    final destination = await Directory(p.join(root.path, 'destination'))
        .create(recursive: true);
    final oldFile = await createFile('destination/album/old.jpg', 'old');

    await expectLater(
      FileUtils.copyOrMove(
        [sourceDirectory.path],
        destination.path,
        move: false,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await oldFile.readAsString(), 'old');
    expect(await sourceFile.readAsString(), 'new');

    await FileUtils.copyOrMove(
      [sourceDirectory.path],
      destination.path,
      move: false,
      overwrite: true,
    );

    expect(await oldFile.exists(), isFalse);
    expect(
      await File(p.join(destination.path, 'album/new.jpg')).readAsString(),
      'new',
    );
    expect(await sourceFile.readAsString(), 'new');
  });

  test('rejects copying a folder into itself', () async {
    final source =
        await Directory(p.join(root.path, 'album')).create(recursive: true);
    final destination =
        await Directory(p.join(source.path, 'nested')).create(recursive: true);

    await expectLater(
      FileUtils.copyOrMove(
        [source.path],
        destination.path,
        move: true,
        overwrite: true,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          contains('inside itself'),
        ),
      ),
    );

    expect(await source.exists(), isTrue);
  });

  test('rejects a destination symlink that aliases the source parent',
      () async {
    final source = await createFile('source/image.jpg', 'original');
    final destinationAlias = Link(p.join(root.path, 'destination-alias'));
    await destinationAlias.create(source.parent.path);

    await expectLater(
      FileUtils.copyOrMove(
        [source.path],
        destinationAlias.path,
        move: true,
        overwrite: true,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          contains('same item'),
        ),
      ),
    );

    expect(await source.readAsString(), 'original');
  });

  test('rejects a destination symlink into the source subtree', () async {
    final sourceFile = await createFile('album/nested/image.jpg', 'photo');
    final source = sourceFile.parent.parent;
    final destinationAlias = Link(p.join(root.path, 'nested-alias'));
    await destinationAlias.create(sourceFile.parent.path);

    await expectLater(
      FileUtils.copyOrMove(
        [source.path],
        destinationAlias.path,
        move: false,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          contains('inside itself'),
        ),
      ),
    );

    expect(await sourceFile.readAsString(), 'photo');
  });

  test('pins the destination when its parent symlink is retargeted', () async {
    final source = await createFile('source/image.jpg', 'original');
    final firstDestination =
        await Directory(p.join(root.path, 'first-destination')).create();
    final secondDestination =
        await Directory(p.join(root.path, 'second-destination')).create();
    final destinationAlias = Link(p.join(root.path, 'destination-alias'));
    await destinationAlias.create(firstDestination.path);

    await FileUtils.copyOrMove(
      [source.path],
      destinationAlias.path,
      move: false,
      afterPreflight: () async {
        await destinationAlias.delete();
        await destinationAlias.create(secondDestination.path);
      },
    );

    expect(
      await File(p.join(firstDestination.path, 'image.jpg')).readAsString(),
      'original',
    );
    expect(
      await File(p.join(secondDestination.path, 'image.jpg')).exists(),
      isFalse,
    );
    expect(await source.readAsString(), 'original');
  });

  test('pins a move source when its parent symlink is retargeted', () async {
    final original = await createFile('first-source/image.jpg', 'original');
    final replacement =
        await createFile('second-source/image.jpg', 'replacement');
    final sourceAlias = Link(p.join(root.path, 'source-alias'));
    await sourceAlias.create(original.parent.path);
    final destination =
        await Directory(p.join(root.path, 'destination')).create();

    await FileUtils.copyOrMove(
      [p.join(sourceAlias.path, 'image.jpg')],
      destination.path,
      move: true,
      afterPreflight: () async {
        await sourceAlias.delete();
        await sourceAlias.create(replacement.parent.path);
      },
    );

    expect(await original.exists(), isFalse);
    expect(await replacement.readAsString(), 'replacement');
    expect(
      await File(p.join(destination.path, 'image.jpg')).readAsString(),
      'original',
    );
  });

  test('does not delete an item recreated at the source path', () async {
    final source = await createFile('source/image.jpg', 'original');
    final destination =
        await Directory(p.join(root.path, 'destination')).create();

    await FileUtils.copyOrMove(
      [source.path],
      destination.path,
      move: true,
      beforeMoveDelete: () async {
        await File(source.path).writeAsString('replacement');
      },
    );

    expect(await source.readAsString(), 'replacement');
    expect(
      await File(p.join(destination.path, 'image.jpg')).readAsString(),
      'original',
    );
  });

  test('does not delete a recreated descendant of a moved directory', () async {
    final sourceFile = await createFile('album/image.jpg', 'original');
    final source = sourceFile.parent;
    final destination =
        await Directory(p.join(root.path, 'destination')).create();

    await FileUtils.copyOrMove(
      [source.path],
      destination.path,
      move: true,
      beforeMoveDelete: () async {
        await source.create();
        await File(p.join(source.path, 'image.jpg'))
            .writeAsString('replacement');
      },
    );

    expect(await sourceFile.readAsString(), 'replacement');
    expect(
      await File(p.join(destination.path, 'album/image.jpg')).readAsString(),
      'original',
    );
  });

  test('restores a moved directory when an open descendant is modified',
      () async {
    final sourceFile = await createFile('album/image.jpg', 'original');
    final source = sourceFile.parent;
    final destination =
        await Directory(p.join(root.path, 'destination')).create();
    final openFile = await sourceFile.open(mode: FileMode.append);
    addTearDown(openFile.close);

    await expectLater(
      FileUtils.copyOrMove(
        [source.path],
        destination.path,
        move: true,
        beforeMoveDelete: () async {
          await openFile.writeString('-updated');
          await openFile.flush();
        },
      ),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          contains('changed while it was being moved'),
        ),
      ),
    );

    expect(await sourceFile.readAsString(), 'original-updated');
    expect(
      await File(p.join(destination.path, 'album/image.jpg')).readAsString(),
      'original',
    );
  });

  test('restores reserved sources when committing a copy fails', () async {
    final source = await createFile('source/image.jpg', 'original');
    final destination =
        await Directory(p.join(root.path, 'destination')).create();
    final target = File(p.join(destination.path, 'image.jpg'));

    await expectLater(
      FileUtils.copyOrMove(
        [source.path],
        destination.path,
        move: true,
        afterPreflight: () => target.writeAsString('external'),
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await source.readAsString(), 'original');
    expect(await target.readAsString(), 'external');
  });

  test('uses a visible recovery path when the original path is occupied',
      () async {
    final source = await createFile('source/image.jpg', 'original');
    final destination =
        await Directory(p.join(root.path, 'destination')).create();
    final target = File(p.join(destination.path, 'image.jpg'));

    await expectLater(
      FileUtils.copyOrMove(
        [source.path],
        destination.path,
        move: true,
        afterPreflight: () async {
          await File(source.path).writeAsString('replacement');
          await target.writeAsString('external');
        },
      ),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          contains('.foto-recovered-'),
        ),
      ),
    );

    expect(await source.readAsString(), 'replacement');
    expect(await target.readAsString(), 'external');
    final recovered = source.parent.listSync().whereType<File>().singleWhere(
        (file) => p.basename(file.path).contains('.foto-recovered-'));
    expect(await recovered.readAsString(), 'original');
  });

  test('moves dangling symbolic links without following them', () async {
    final source = Link(p.join(root.path, 'missing-image'));
    await source.create('missing.jpg');
    final destination =
        await Directory(p.join(root.path, 'destination')).create();

    await FileUtils.copyOrMove(
      [source.path],
      destination.path,
      move: true,
    );

    expect(await source.exists(), isFalse);
    final copied = Link(p.join(destination.path, 'missing-image'));
    expect(await copied.target(), 'missing.jpg');
  });

  test('macOS directory copies preserve mode, timestamps, and xattrs',
      () async {
    if (!Platform.isMacOS) return;

    final sourceFile = await createFile('private-album/image.jpg', 'photo');
    final source = sourceFile.parent;
    expect((await Process.run('/bin/chmod', ['700', source.path])).exitCode, 0);
    expect(
      (await Process.run('/usr/bin/xattr', [
        '-w',
        'com.openai.foto-test',
        'preserved',
        source.path,
      ]))
          .exitCode,
      0,
    );
    final sourceModified = (await source.stat()).modified;
    final destination =
        await Directory(p.join(root.path, 'destination')).create();

    await FileUtils.copyOrMove(
      [source.path],
      destination.path,
      move: false,
    );

    final copied = Directory(p.join(destination.path, 'private-album'));
    final copiedStat = await copied.stat();
    expect(copiedStat.mode & 0x1ff, 0x1c0);
    expect(
      copiedStat.modified.millisecondsSinceEpoch,
      sourceModified.millisecondsSinceEpoch,
    );
    final xattr = await Process.run('/usr/bin/xattr', [
      '-p',
      'com.openai.foto-test',
      copied.path,
    ]);
    expect(xattr.exitCode, 0);
    expect(xattr.stdout.toString().trim(), 'preserved');
  });

  test('rename detects folder collisions', () async {
    final source = await createFile('source.jpg', 'source');
    await Directory(p.join(root.path, 'occupied')).create();

    final renamed = FileUtils.tryRename(source.path, 'occupied');

    expect(renamed, isNull);
    expect(await source.readAsString(), 'source');
  });
}

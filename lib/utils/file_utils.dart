import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;

import '../components/dialogs.dart';
import '../model/file_metadata.dart';
import 'platform_utils.dart';

class FileUtils {
  static const MethodChannel _mChannel =
      MethodChannel('foto_file_utils/messages');

  static int _temporaryPathSequence = 0;

  static Future<DateTime> getCreationDate(String filepath) async {
    final double epoch =
        await _mChannel.invokeMethod<double>('getCreationDate', filepath) ?? 0;
    return DateTime.fromMicrosecondsSinceEpoch(
      (epoch * Duration.microsecondsPerSecond).round(),
    );
  }

  static Future<DateTime> getModificationDate(String filepath) async {
    final double epoch =
        await _mChannel.invokeMethod<double>('getModificationDate', filepath) ??
            0;
    return DateTime.fromMicrosecondsSinceEpoch(
      (epoch * Duration.microsecondsPerSecond).round(),
    );
  }

  static Future<List<FileMetadata>> scanDirectory(String path) async {
    try {
      final entries = await _mChannel.invokeMethod<List<Object?>>(
            'scanDirectory',
            path,
          ) ??
          const <Object?>[];
      return entries
          .map((entry) => FileMetadata.fromPlatformMap(
                Map<Object?, Object?>.from(entry! as Map),
              ))
          .toList(growable: false);
    } on MissingPluginException {
      return _scanDirectoryFallback(path);
    }
  }

  static Future<List<FileMetadata>> _scanDirectoryFallback(String path) async {
    final entities = await Directory(path)
        .list(recursive: false, followLinks: false)
        .toList();
    final entries = await Future.wait(
      entities.where((entity) => entity is File || entity is Directory).map(
        (entity) async {
          final stat = await entity.stat();
          return FileMetadata(
            path: entity.path,
            entityType: stat.type,
            creationDate: stat.changed,
            modificationDate: stat.modified,
            size: entity is File ? stat.size : null,
          );
        },
      ),
    );
    return entries;
  }

  static Future<bool> confirmDelete(
    BuildContext context,
    List<String> files, {
    Color? barrierColor,
  }) async {
    final t = AppLocalizations.of(context)!;
    final title = files.length == 1
        ? t.deleteTitleSingle(p.basename(files[0]))
        : t.deleteTitleMultiple(files.length);
    final text = t.deleteText(files.length);

    final confirmed = await FotoDialog.confirm(
      context: context,
      barrierColor: barrierColor,
      title: title,
      text: text,
      confirmLabel: t.menuEditDelete,
      onConfirmed: (dialogContext) {
        Navigator.of(dialogContext).pop(true);
      },
      onCancel: (dialogContext) {
        Navigator.of(dialogContext).pop(false);
      },
    );

    if (confirmed != true) return false;

    try {
      await delete(files);
      return true;
    } catch (error) {
      if (context.mounted) {
        await _showError(context, error);
      }
      return false;
    }
  }

  static Future<void> delete(List<String> files) async {
    await Future.wait(files.map(PlatformUtils.moveToTrash));
  }

  static Future<void> tryPaste(
    BuildContext context,
    String destination,
    bool move,
  ) async {
    try {
      final files = await Pasteboard.files();
      if (!context.mounted) return;
      await tryCopyOrMove(context, files, destination, move);
    } catch (error) {
      if (context.mounted) {
        await _showError(context, error);
      }
    }
  }

  static Future<void> tryCopyOrMove(
    BuildContext context,
    List<String> files,
    String destination,
    bool move,
  ) async {
    final operations = await _buildOperations(files, destination);
    if (operations.isEmpty) return;

    final conflicts = await _conflictingTargets(operations);
    if (!context.mounted) return;
    var overwrite = false;
    if (conflicts.isNotEmpty) {
      final confirmed = await FotoDialog.confirm(
        context: context,
        text: AppLocalizations.of(context)!.overwriteConfirm,
        isDestructive: true,
        onConfirmed: (dialogContext) {
          Navigator.of(dialogContext).pop(true);
        },
        onCancel: (dialogContext) {
          Navigator.of(dialogContext).pop(false);
        },
      );
      if (confirmed != true) return;
      overwrite = true;
    }

    await _copyOrMove(operations, move: move, overwrite: overwrite);
  }

  /// Copies or moves [files] into [destination].
  ///
  /// This is the non-UI operation used by paste. Existing files and folders
  /// cause a [FileSystemException] unless [overwrite] is true. Sources are
  /// removed for a move only after every item has been copied successfully.
  static Future<void> copyOrMove(
    List<String> files,
    String destination, {
    required bool move,
    bool overwrite = false,
    @visibleForTesting Future<void> Function()? afterPreflight,
    @visibleForTesting Future<void> Function()? beforeMoveDelete,
  }) async {
    final operations = await _buildOperations(files, destination);
    if (operations.isEmpty) return;

    final conflicts = await _conflictingTargets(operations);
    if (conflicts.isNotEmpty && !overwrite) {
      throw FileSystemException(
        'An item with this name already exists',
        conflicts.first,
      );
    }

    await _copyOrMove(
      operations,
      move: move,
      overwrite: overwrite,
      afterPreflight: afterPreflight,
      beforeMoveDelete: beforeMoveDelete,
    );
  }

  static Future<List<_FileOperation>> _buildOperations(
    List<String> files,
    String destination,
  ) async {
    final normalizedDestination = p.normalize(p.absolute(destination));
    if (!await Directory(normalizedDestination).exists()) {
      throw FileSystemException(
        'The paste destination is not a folder',
        normalizedDestination,
      );
    }
    final canonicalDestination =
        await Directory(normalizedDestination).resolveSymbolicLinks();
    final bool caseSensitive =
        await _isCaseSensitiveDirectory(normalizedDestination);

    final operations = <_FileOperation>[];
    final sourceKeys = <String>{};
    final targetKeys = <String>{};

    for (final input in files) {
      final source = p.normalize(p.absolute(input));
      final canonicalSource = await _canonicalPathPreservingLeaf(source);
      final sourceKey = _pathKey(canonicalSource, caseSensitive: caseSensitive);
      if (!sourceKeys.add(sourceKey)) {
        continue;
      }

      final sourceType =
          await FileSystemEntity.type(source, followLinks: false);
      if (sourceType == FileSystemEntityType.notFound) {
        throw FileSystemException('The source item does not exist', source);
      }
      if (!_isCopyableType(sourceType)) {
        throw FileSystemException('The source item cannot be copied', source);
      }

      final basename = p.basename(source);
      if (basename.isEmpty || basename == p.separator) {
        throw FileSystemException('The source item has no valid name', source);
      }
      final target = p.join(normalizedDestination, basename);
      final canonicalTarget = p.join(canonicalDestination, basename);
      if (!targetKeys.add(
        _pathKey(canonicalTarget, caseSensitive: caseSensitive),
      )) {
        throw FileSystemException(
          'Multiple source items have the same name: $basename',
          target,
        );
      }

      if (_samePath(
        canonicalSource,
        canonicalTarget,
        caseSensitive: caseSensitive,
      )) {
        throw FileSystemException(
          'The source and destination are the same item',
          source,
        );
      }
      if (sourceType == FileSystemEntityType.directory &&
          _isWithin(
            canonicalSource,
            canonicalTarget,
            caseSensitive: caseSensitive,
          )) {
        throw FileSystemException(
          'A folder cannot be copied inside itself',
          source,
        );
      }

      operations.add(_FileOperation(
        source,
        target,
        sourceType,
        canonicalSource,
        canonicalTarget,
        caseSensitive,
      ));
    }

    for (var index = 0; index < operations.length; index++) {
      final operation = operations[index];
      for (var otherIndex = index + 1;
          otherIndex < operations.length;
          otherIndex++) {
        final other = operations[otherIndex];
        if (_isWithin(
              operation.canonicalSource,
              other.canonicalSource,
              caseSensitive: operation.caseSensitive,
            ) ||
            _isWithin(
              other.canonicalSource,
              operation.canonicalSource,
              caseSensitive: operation.caseSensitive,
            )) {
          throw FileSystemException(
            'A folder and one of its contents cannot be pasted together',
            operation.source,
          );
        }
        if (_samePath(
              operation.canonicalTarget,
              other.canonicalSource,
              caseSensitive: operation.caseSensitive,
            ) ||
            _samePath(
              other.canonicalTarget,
              operation.canonicalSource,
              caseSensitive: operation.caseSensitive,
            )) {
          throw FileSystemException(
            'A paste target cannot also be one of its sources',
            operation.target,
          );
        }
      }
    }

    return operations;
  }

  static Future<List<String>> _conflictingTargets(
    List<_FileOperation> operations,
  ) async {
    final conflicts = <String>[];
    for (final operation in operations) {
      if (await _exists(operation.canonicalTarget)) {
        conflicts.add(operation.target);
      }
    }
    return conflicts;
  }

  static Future<void> _copyOrMove(
    List<_FileOperation> operations, {
    required bool move,
    required bool overwrite,
    Future<void> Function()? afterPreflight,
    Future<void> Function()? beforeMoveDelete,
  }) async {
    if (!move) {
      await afterPreflight?.call();
      for (final operation in operations) {
        await _copySafely(
          operation,
          source: operation.canonicalSource,
          overwrite: overwrite,
        );
      }
      return;
    }

    final reservations = <_ReservedSource>[];
    try {
      // Atomically remove each selected entity from its public path before
      // copying. A file or directory recreated at that path is therefore a
      // new entity and can never be deleted as part of this move.
      for (final operation in operations) {
        final original = await _snapshotSource(operation.canonicalSource);
        final reservedPath =
            await _unusedSiblingPath(operation.canonicalSource, 'move');
        await _renameEntity(operation.canonicalSource, reservedPath);
        final reservation = _ReservedSource(operation, reservedPath);
        reservations.add(reservation);

        final reserved = await _snapshotSource(reservedPath);
        if (!reserved.isSameEntityAs(original)) {
          throw FileSystemException(
            'The source item changed while it was being moved',
            operation.source,
          );
        }
      }

      await afterPreflight?.call();

      for (final reservation in reservations) {
        reservation.snapshot = await _snapshotSourceTree(
          reservation.path,
          reservation.operation.type,
        );
      }

      for (final reservation in reservations) {
        await _copySafely(
          reservation.operation,
          source: reservation.path,
          overwrite: overwrite,
        );
      }

      await beforeMoveDelete?.call();

      // Recheck each tree immediately before its deletion to catch edits
      // through already-open file handles.
      for (final reservation in reservations) {
        await _verifyReservedSourceUnchanged(reservation);
        await _deleteEntity(reservation.path, reservation.operation.type);
      }
    } catch (error, stackTrace) {
      final recoveredPaths = await _restoreReservedSources(reservations);
      if (recoveredPaths.isNotEmpty) {
        throw FileSystemException(
          'The move failed. Source items were recovered as: '
          '${recoveredPaths.join(', ')}',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<void> _copySafely(
    _FileOperation operation, {
    required String source,
    required bool overwrite,
  }) async {
    final target = operation.canonicalTarget;
    final stagingPath = await _unusedSiblingPath(target, 'copy');
    String? backupPath;

    try {
      await _copyEntity(source, stagingPath, operation.type);

      if (await _exists(target)) {
        if (!overwrite) {
          throw FileSystemException(
            'An item with this name already exists',
            operation.target,
          );
        }
        backupPath = await _unusedSiblingPath(target, 'backup');
        await _renameEntity(target, backupPath);
      }

      try {
        await _renameEntity(stagingPath, target);
      } catch (_) {
        if (backupPath != null &&
            await _exists(backupPath) &&
            !await _exists(target)) {
          await _renameEntity(backupPath, target);
          backupPath = null;
        }
        rethrow;
      }

      if (backupPath != null) {
        await _deleteEntityAtPath(backupPath);
      }
    } catch (_) {
      if (await _exists(stagingPath)) {
        await _deleteEntityAtPath(stagingPath);
      }
      rethrow;
    }
  }

  static Future<void> _copyEntity(
    String source,
    String target,
    FileSystemEntityType type,
  ) async {
    if (Platform.isMacOS &&
        (type == FileSystemEntityType.file ||
            type == FileSystemEntityType.directory)) {
      final ProcessResult result = await Process.run(
        '/usr/bin/ditto',
        ['--rsrc', '--extattr', '--acl', source, target],
      );
      if (result.exitCode != 0) {
        throw FileSystemException(
          result.stderr.toString().trim().isEmpty
              ? 'The item could not be copied'
              : result.stderr.toString().trim(),
          source,
        );
      }
      return;
    }

    switch (type) {
      case FileSystemEntityType.file:
        await File(source).copy(target);
        return;
      case FileSystemEntityType.directory:
        await Directory(target).create();
        await for (final entity in Directory(source).list(followLinks: false)) {
          final childType =
              await FileSystemEntity.type(entity.path, followLinks: false);
          if (!_isCopyableType(childType)) {
            throw FileSystemException(
              'The source item cannot be copied',
              entity.path,
            );
          }
          await _copyEntity(
            entity.path,
            p.join(target, p.basename(entity.path)),
            childType,
          );
        }
        return;
      case FileSystemEntityType.link:
        await Link(target).create(await Link(source).target());
        return;
      default:
        throw FileSystemException('The source item cannot be copied', source);
    }
  }

  static Future<void> _renameEntity(String source, String target) async {
    final type = await FileSystemEntity.type(source, followLinks: false);
    switch (type) {
      case FileSystemEntityType.file:
        await File(source).rename(target);
        return;
      case FileSystemEntityType.directory:
        await Directory(source).rename(target);
        return;
      case FileSystemEntityType.link:
        await Link(source).rename(target);
        return;
      default:
        throw FileSystemException('The item cannot be renamed', source);
    }
  }

  static Future<void> _deleteEntity(
    String path,
    FileSystemEntityType type,
  ) async {
    switch (type) {
      case FileSystemEntityType.file:
        await File(path).delete();
        return;
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
        return;
      case FileSystemEntityType.link:
        await Link(path).delete();
        return;
      default:
        throw FileSystemException('The item cannot be deleted', path);
    }
  }

  static Future<void> _deleteEntityAtPath(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type != FileSystemEntityType.notFound) {
      await _deleteEntity(path, type);
    }
  }

  static Future<bool> _exists(String path) async {
    return await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.notFound;
  }

  static Future<_SourceSnapshot> _snapshotSource(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('The source item does not exist', path);
    }

    final identities = await _readFileIdentities([path]);
    return _snapshotSourceWithIdentity(path, type, identities.single);
  }

  static Future<void> _verifySourceUnchanged(
    String path,
    _SourceTreeSnapshot expected,
  ) async {
    final current = await _snapshotSourceTree(path, expected.rootType);
    if (current != expected) {
      throw FileSystemException(
        'The source item changed while it was being moved',
        path,
      );
    }
  }

  static Future<_SourceTreeSnapshot> _snapshotSourceTree(
    String root,
    FileSystemEntityType rootType,
  ) async {
    final paths = <String>[root];
    if (rootType == FileSystemEntityType.directory) {
      await for (final entity
          in Directory(root).list(recursive: true, followLinks: false)) {
        paths.add(entity.path);
      }
    }
    paths.sort();

    final identities = await _readFileIdentities(paths);
    final entries = <String, _SourceSnapshot>{};
    for (var index = 0; index < paths.length; index++) {
      final path = paths[index];
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        throw FileSystemException('The source item does not exist', path);
      }
      entries[p.relative(path, from: root)] =
          await _snapshotSourceWithIdentity(path, type, identities[index]);
    }
    return _SourceTreeSnapshot(rootType, entries);
  }

  static Future<_SourceSnapshot> _snapshotSourceWithIdentity(
    String path,
    FileSystemEntityType type,
    String identity,
  ) async {
    final stat = await FileStat.stat(path);
    return _SourceSnapshot(
      identity: identity,
      type: type,
      size: stat.size,
      mode: stat.mode,
      modified: stat.modified,
      changed: stat.changed,
    );
  }

  static Future<List<String>> _readFileIdentities(List<String> paths) async {
    if (!Platform.isMacOS && !Platform.isLinux) {
      return paths.map((path) => p.normalize(p.absolute(path))).toList();
    }

    const chunkSize = 128;
    final identities = <String>[];
    for (var offset = 0; offset < paths.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, paths.length);
      final chunk = paths.sublist(offset, end);
      final formatArguments = Platform.isMacOS
          ? const ['-f', '%d:%i', '--']
          : const ['-c', '%d:%i', '--'];
      final result = await Process.run(
        '/usr/bin/stat',
        [...formatArguments, ...chunk],
      );
      if (result.exitCode != 0) {
        throw FileSystemException(
          result.stderr.toString().trim().isEmpty
              ? 'The source identity could not be read'
              : result.stderr.toString().trim(),
          chunk.first,
        );
      }

      final chunkIdentities = const LineSplitter().convert(
        result.stdout.toString().trimRight(),
      );
      if (chunkIdentities.length != chunk.length) {
        throw FileSystemException(
          'The source identity could not be read',
          chunk.first,
        );
      }
      identities.addAll(chunkIdentities);
    }
    return identities;
  }

  static Future<void> _verifyReservedSourceUnchanged(
    _ReservedSource reservation,
  ) async {
    final expected = reservation.snapshot;
    if (expected == null) {
      throw StateError('The reserved source was not snapshotted');
    }
    try {
      await _verifySourceUnchanged(reservation.path, expected);
    } on FileSystemException {
      throw FileSystemException(
        'The source item changed while it was being moved',
        reservation.operation.source,
      );
    }
  }

  static Future<List<String>> _restoreReservedSources(
    List<_ReservedSource> reservations,
  ) async {
    final recoveredPaths = <String>[];
    for (final reservation in reservations.reversed) {
      try {
        if (!await _exists(reservation.path)) continue;

        var restorePath = reservation.operation.canonicalSource;
        if (await _exists(restorePath)) {
          restorePath = await _unusedRecoveryPath(restorePath);
        }
        await _renameEntity(reservation.path, restorePath);
        if (restorePath != reservation.operation.canonicalSource) {
          recoveredPaths.add(restorePath);
        }
      } catch (_) {
        // Keep the reserved entity in place and surface its exact location.
        recoveredPaths.add(reservation.path);
      }
    }
    return recoveredPaths;
  }

  static Future<String> _unusedRecoveryPath(String original) async {
    while (true) {
      final sequence = _temporaryPathSequence++;
      final basename = p.basename(original);
      final extension = p.extension(basename);
      final stem = extension.isEmpty
          ? basename
          : basename.substring(0, basename.length - extension.length);
      final candidate = p.join(
        p.dirname(original),
        '$stem.foto-recovered-$pid-'
        '${DateTime.now().microsecondsSinceEpoch}-$sequence$extension',
      );
      if (!await _exists(candidate)) return candidate;
    }
  }

  static bool _isCopyableType(FileSystemEntityType type) {
    return type == FileSystemEntityType.file ||
        type == FileSystemEntityType.directory ||
        type == FileSystemEntityType.link;
  }

  static Future<String> _unusedSiblingPath(
    String target,
    String purpose,
  ) async {
    while (true) {
      final sequence = _temporaryPathSequence++;
      final candidate = p.join(
        p.dirname(target),
        '.${p.basename(target)}.foto-$purpose-$pid-${DateTime.now().microsecondsSinceEpoch}-$sequence',
      );
      if (!await _exists(candidate)) return candidate;
    }
  }

  static Future<String> _canonicalPathPreservingLeaf(String path) async {
    final String canonicalParent =
        await Directory(p.dirname(path)).resolveSymbolicLinks();
    return p.join(canonicalParent, p.basename(path));
  }

  static Future<bool> _isCaseSensitiveDirectory(String directory) async {
    final String suffix =
        '$pid-${DateTime.now().microsecondsSinceEpoch}-${_temporaryPathSequence++}';
    final File lowercase = File(p.join(directory, '.foto-case-$suffix-a'));
    final File uppercase = File(p.join(directory, '.foto-case-$suffix-A'));
    try {
      await lowercase.create(exclusive: true);
      return !await uppercase.exists();
    } finally {
      if (await lowercase.exists()) {
        await lowercase.delete();
      }
    }
  }

  static String _pathKey(String path, {required bool caseSensitive}) {
    final normalized = p.normalize(p.absolute(path));
    return caseSensitive ? normalized : normalized.toLowerCase();
  }

  static bool _samePath(
    String first,
    String second, {
    required bool caseSensitive,
  }) {
    return _pathKey(first, caseSensitive: caseSensitive) ==
        _pathKey(second, caseSensitive: caseSensitive);
  }

  static bool _isWithin(
    String parent,
    String child, {
    required bool caseSensitive,
  }) {
    final parentKey = _pathKey(parent, caseSensitive: caseSensitive);
    final childKey = _pathKey(child, caseSensitive: caseSensitive);
    return p.isWithin(parentKey, childKey);
  }

  static Future<void> _showError(
    BuildContext context,
    Object error,
  ) async {
    final message = error is FileSystemException
        ? error.message
        : error is PlatformException
            ? error.message ?? error.code
            : error.toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext)!.appName),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(dialogContext)!.ok),
          ),
        ],
      ),
    );
  }

  static String? tryRename(
    String originalName,
    String newName,
  ) {
    try {
      if (newName.isEmpty) return null;
      if (!newName.contains(p.separator)) {
        newName = p.join(p.dirname(originalName), newName);
      }
      if (FileSystemEntity.typeSync(newName, followLinks: false) !=
          FileSystemEntityType.notFound) {
        return null;
      }

      final type = FileSystemEntity.typeSync(originalName, followLinks: false);
      switch (type) {
        case FileSystemEntityType.file:
          File(originalName).renameSync(newName);
          break;
        case FileSystemEntityType.directory:
          Directory(originalName).renameSync(newName);
          break;
        case FileSystemEntityType.link:
          Link(originalName).renameSync(newName);
          break;
        default:
          return null;
      }
      return newName;
    } catch (_) {
      return null;
    }
  }
}

class _FileOperation {
  const _FileOperation(
    this.source,
    this.target,
    this.type,
    this.canonicalSource,
    this.canonicalTarget,
    this.caseSensitive,
  );

  final String source;
  final String target;
  final FileSystemEntityType type;
  final String canonicalSource;
  final String canonicalTarget;
  final bool caseSensitive;
}

class _SourceSnapshot {
  const _SourceSnapshot({
    required this.identity,
    required this.type,
    required this.size,
    required this.mode,
    required this.modified,
    required this.changed,
  });

  final String identity;
  final FileSystemEntityType type;
  final int size;
  final int mode;
  final DateTime modified;
  final DateTime changed;

  bool isSameEntityAs(_SourceSnapshot other) {
    return identity == other.identity && type == other.type;
  }

  @override
  bool operator ==(Object other) {
    return other is _SourceSnapshot &&
        identity == other.identity &&
        type == other.type &&
        size == other.size &&
        mode == other.mode &&
        modified == other.modified &&
        changed == other.changed;
  }

  @override
  int get hashCode => Object.hash(
        identity,
        type,
        size,
        mode,
        modified,
        changed,
      );
}

class _SourceTreeSnapshot {
  const _SourceTreeSnapshot(this.rootType, this.entries);

  final FileSystemEntityType rootType;
  final Map<String, _SourceSnapshot> entries;

  @override
  bool operator ==(Object other) {
    if (other is! _SourceTreeSnapshot ||
        rootType != other.rootType ||
        entries.length != other.entries.length) {
      return false;
    }
    return entries.entries.every(
      (entry) => other.entries[entry.key] == entry.value,
    );
  }

  @override
  int get hashCode => Object.hash(rootType, Object.hashAll(entries.entries));
}

class _ReservedSource {
  _ReservedSource(this.operation, this.path);

  final _FileOperation operation;
  final String path;
  _SourceTreeSnapshot? snapshot;
}

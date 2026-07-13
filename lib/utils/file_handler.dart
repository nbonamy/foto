// Copyright 2018 Evo Stamatov. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';

const MethodChannel _mChannel = MethodChannel('foto_file_handler/messages');
const EventChannel _eChannel = EventChannel('foto_file_handler/events');
Stream<String>? _stream;

/// Returns the raw filesystem path supplied by macOS.
///
///   * the initially stored path (possibly null), on successful invocation;
///   * a [PlatformException], if the invocation failed in the platform plugin.
Future<String?> getInitialFile() async {
  return _mChannel.invokeMethod<String>('getInitialFile');
}

/// Returns a file [Uri] for the initially stored filesystem path.
Future<Uri?> getInitialUri() async {
  final file = await getInitialFile();
  return file == null ? null : Uri.file(file);
}

/// Sets up a broadcast stream for receiving incoming link change events.
///
/// Returns a broadcast [Stream] which emits events to listeners as follows:
///
///   * a raw filesystem path ([String]) for each successful
///   event received from the platform plugin;
///   * an error event containing a [PlatformException] for each error event
///   received from the platform plugin.
///
/// Errors occurring during stream activation or deactivation are reported
/// through the `FlutterError` facility. Stream activation happens only when
/// stream listener count changes from 0 to 1. Stream deactivation happens
/// only when stream listener count changes from 1 to 0.
Stream<String>? getStream() {
  _stream ??= _eChannel.receiveBroadcastStream().cast<String>();
  return _stream;
}

/// A convenience alias for the raw filesystem path stream.
///
/// Refer to `getLinksStream` about error/exception details.
///
/// If the app was stared by a link intent or user activity the stream will
/// not emit that initial uri - query either the `getInitialFile` instead.
Stream<String>? getFilesStream() {
  return getStream();
}

/// Transforms each raw filesystem path into a file [Uri].
///
/// Refer to `getLinksStream` about error/exception details.
///
/// If the app was stared by a link intent or user activity the stream will
/// not emit that initial uri - query either the `getInitialUri` instead.
Stream<Uri>? getUriFilesStream() {
  return getStream()?.map(Uri.file);
}

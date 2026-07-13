import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/utils/file_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('foto_file_handler/messages');
  const rawPath = '/tmp/foto #1?100%20 done.jpg';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getInitialFile');
      return rawPath;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns native filesystem paths without URI decoding', () async {
    expect(await getInitialFile(), rawPath);
  });

  test('creates file URIs without interpreting path punctuation', () async {
    final uri = await getInitialUri();

    expect(uri, isNotNull);
    expect(uri!.scheme, 'file');
    expect(uri.toFilePath(), rawPath);
  });
}

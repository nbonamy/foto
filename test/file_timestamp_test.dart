import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/utils/file_utils.dart';
import 'package:foto/utils/image_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fileChannel = MethodChannel('foto_file_utils/messages');
  const imageChannel = MethodChannel('foto_image_utils/messages');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (_) async => 1.2346);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imageChannel, (_) async => 1.2346);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imageChannel, null);
  });

  test('file timestamps preserve fractional epoch seconds', () async {
    expect(
      (await FileUtils.getCreationDate('/tmp/image.jpg'))
          .microsecondsSinceEpoch,
      1234600,
    );
    expect(
      (await FileUtils.getModificationDate('/tmp/image.jpg'))
          .microsecondsSinceEpoch,
      1234600,
    );
  });

  test('capture timestamps preserve fractional epoch seconds', () async {
    expect(
      (await ImageUtils.getCreationDate('/tmp/image.jpg'))
          .microsecondsSinceEpoch,
      1234600,
    );
  });
}

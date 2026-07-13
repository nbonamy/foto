import 'package:flutter_test/flutter_test.dart';
import 'package:foto/utils/utils.dart';

void main() {
  test('path titles preserve root and extract filenames', () {
    expect(Utils.pathTitle('/'), '/');
    expect(Utils.pathTitle('/Users/nicolas/Pictures/photo.jpg'), 'photo.jpg');
    expect(Utils.pathTitle(null), isNull);
  });
}

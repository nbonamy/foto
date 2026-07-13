import 'package:exif/exif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/photo_metadata.dart';

void main() {
  test('gps exif converts degree minute second ratios and hemispheres', () {
    final location = photoLocationFromExif({
      'GPS GPSLatitude': _tag(
        '64, 8, 12',
        IfdRatios([Ratio(64, 1), Ratio(8, 1), Ratio(12, 1)]),
      ),
      'GPS GPSLatitudeRef': _tag('N', const IfdNone()),
      'GPS GPSLongitude': _tag(
        '21, 56, 24',
        IfdRatios([Ratio(21, 1), Ratio(56, 1), Ratio(24, 1)]),
      ),
      'GPS GPSLongitudeRef': _tag('W', const IfdNone()),
    });

    expect(location, isNotNull);
    expect(location!.latitude, closeTo(64.136667, 0.000001));
    expect(location.longitude, closeTo(-21.94, 0.000001));
  });

  test('invalid or incomplete gps exif is ignored', () {
    expect(photoLocationFromExif({}), isNull);
    expect(
      photoLocationFromExif({
        'GPS GPSLatitude': _tag(
          '200, 0, 0',
          IfdRatios([Ratio(200, 1), Ratio(0, 1), Ratio(0, 1)]),
        ),
        'GPS GPSLatitudeRef': _tag('N', const IfdNone()),
        'GPS GPSLongitude': _tag(
          '1, 0, 0',
          IfdRatios([Ratio(1, 1), Ratio(0, 1), Ratio(0, 1)]),
        ),
        'GPS GPSLongitudeRef': _tag('E', const IfdNone()),
      }),
      isNull,
    );
    expect(
      photoLocationFromExif({
        'GPS GPSLatitude': _tag(
          '64, 0, 0',
          IfdRatios([Ratio(64, 1), Ratio(0, 1), Ratio(0, 1)]),
        ),
        'GPS GPSLongitude': _tag(
          '21, 0, 0',
          IfdRatios([Ratio(21, 1), Ratio(0, 1), Ratio(0, 1)]),
        ),
      }),
      isNull,
    );
  });

  test('capture date parses camera exif format', () {
    final date = captureDateFromExif({
      'EXIF DateTimeOriginal': _tag(
        '2024:05:12 16:32:18',
        const IfdNone(),
      ),
    });

    expect(date, DateTime(2024, 5, 12, 16, 32, 18));
    expect(captureDateFromExif({}), isNull);
    expect(
      captureDateFromExif({
        'EXIF DateTimeOriginal': _tag(
          '2024:19:42 28:91:72',
          const IfdNone(),
        ),
      }),
      isNull,
    );
  });
}

IfdTag _tag(String printable, IfdValues values) {
  return IfdTag(
    tag: 0,
    tagType: 'test',
    printable: printable,
    values: values,
  );
}

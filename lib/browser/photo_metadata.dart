import 'package:exif/exif.dart';

class PhotoLocation {
  const PhotoLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is PhotoLocation &&
      latitude == other.latitude &&
      longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

PhotoLocation? photoLocationFromExif(Map<String, IfdTag> exifData) {
  final latitude = _coordinate(
    exifData['GPS GPSLatitude'],
    exifData['GPS GPSLatitudeRef']?.printable,
    positiveReference: 'N',
    negativeReference: 'S',
  );
  final longitude = _coordinate(
    exifData['GPS GPSLongitude'],
    exifData['GPS GPSLongitudeRef']?.printable,
    positiveReference: 'E',
    negativeReference: 'W',
  );
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  return PhotoLocation(latitude: latitude, longitude: longitude);
}

DateTime? captureDateFromExif(Map<String, IfdTag> exifData) {
  final value = exifData['EXIF DateTimeOriginal']?.printable.trim();
  if (value == null || value.isEmpty) return null;
  final match = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(value);
  if (match == null) return null;
  try {
    final parts = [
      for (var index = 1; index <= 6; index += 1)
        int.parse(match.group(index)!),
    ];
    final date = DateTime(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    if (date.year != parts[0] ||
        date.month != parts[1] ||
        date.day != parts[2] ||
        date.hour != parts[3] ||
        date.minute != parts[4] ||
        date.second != parts[5]) {
      return null;
    }
    return date;
  } on FormatException {
    return null;
  }
}

double? _coordinate(
  IfdTag? tag,
  String? reference, {
  required String positiveReference,
  required String negativeReference,
}) {
  final values = tag?.values;
  if (values is! IfdRatios || values.length < 3) return null;
  final ratios = values.ratios;
  if (ratios.any((ratio) => ratio.denominator == 0)) return null;
  final value = ratios[0].toDouble() +
      ratios[1].toDouble() / 60 +
      ratios[2].toDouble() / 3600;
  final normalizedReference = reference?.trim().toUpperCase();
  if (normalizedReference != positiveReference &&
      normalizedReference != negativeReference) {
    return null;
  }
  return normalizedReference == negativeReference ? -value : value;
}

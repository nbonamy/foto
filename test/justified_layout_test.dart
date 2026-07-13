import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/justified_layout.dart';

void main() {
  test('justified rows preserve order and fill every complete row', () {
    const width = 800.0;
    const spacing = 8.0;
    final layout = JustifiedGalleryLayout.compute(
      aspectRatios: const [1, 2, 0.65, 1.5, 0.8, 1.9, 1.1, 0.7],
      availableWidth: width,
      targetRowHeight: 180,
      spacing: spacing,
    );

    expect(
      layout.rows.expand((row) => row.items.map((item) => item.index)),
      orderedEquals(List.generate(8, (index) => index)),
    );
    for (final row in layout.rows.take(layout.rows.length - 1)) {
      final usedWidth = row.items.fold<double>(
            0,
            (total, item) => total + item.width,
          ) +
          spacing * (row.items.length - 1);
      expect(usedWidth, closeTo(width, 0.01));
    }
    expect(
      layout.rows.expand((row) => row.items.map((item) => item.width)).toSet(),
      hasLength(greaterThan(3)),
    );
  });

  test('last row keeps the target height instead of stretching', () {
    final layout = JustifiedGalleryLayout.compute(
      aspectRatios: const [1.4, 0.8],
      availableWidth: 900,
      targetRowHeight: 190,
    );

    expect(layout.rows, hasLength(1));
    expect(layout.rows.single.height, 190);
    final usedWidth = layout.rows.single.items.fold<double>(
          0,
          (total, item) => total + item.width,
        ) +
        8;
    expect(usedWidth, lessThan(900));
  });

  test('large libraries produce finite indexed row geometry', () {
    final ratios = List.generate(
      10000,
      (index) => 0.6 + (index % 17) / 10,
    );
    final layout = JustifiedGalleryLayout.compute(
      aspectRatios: ratios,
      availableWidth: 1400,
    );

    expect(layout.rows.length, lessThan(ratios.length ~/ 2));
    expect(layout.contentHeight.isFinite, isTrue);
    expect(layout.rowForItem(0), isNotNull);
    expect(layout.rowForItem(9999)?.items.last.index, 9999);
  });
}

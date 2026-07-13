import 'dart:math' as math;

class JustifiedGalleryLayout {
  const JustifiedGalleryLayout({
    required this.rows,
    required this.contentHeight,
  });

  final List<JustifiedGalleryRow> rows;
  final double contentHeight;

  static JustifiedGalleryLayout compute({
    required List<double> aspectRatios,
    required double availableWidth,
    double targetRowHeight = 190,
    double minimumRowHeight = 120,
    double maximumRowHeight = 260,
    double spacing = 8,
  }) {
    if (aspectRatios.isEmpty || availableWidth <= 0) {
      return const JustifiedGalleryLayout(rows: [], contentHeight: 0);
    }

    final normalizedRatios = aspectRatios
        .map((ratio) => ratio.isFinite ? ratio.clamp(0.5, 2.5) : 1.0)
        .toList(growable: false);
    final rows = <JustifiedGalleryRow>[];
    var rowStart = 0;
    var rowRatio = 0.0;
    var offset = 0.0;

    void finishRow(int endExclusive, {required bool last}) {
      final count = endExclusive - rowStart;
      if (count <= 0) return;
      final gaps = spacing * math.max(0, count - 1);
      final naturalHeight = (availableWidth - gaps) / rowRatio;
      final height = last
          ? math.min(targetRowHeight, naturalHeight)
          : naturalHeight.clamp(minimumRowHeight, maximumRowHeight);
      final items = <JustifiedGalleryItem>[];
      var usedWidth = 0.0;
      for (var index = rowStart; index < endExclusive; index += 1) {
        var width = normalizedRatios[index] * height;
        if (!last && index == endExclusive - 1) {
          width = math.max(1, availableWidth - gaps - usedWidth);
        }
        items.add(
          JustifiedGalleryItem(
            index: index,
            width: width,
          ),
        );
        usedWidth += width;
      }
      rows.add(
        JustifiedGalleryRow(
          items: items,
          height: height,
          offset: offset,
        ),
      );
      offset += height + spacing;
      rowStart = endExclusive;
      rowRatio = 0;
    }

    for (var index = 0; index < normalizedRatios.length; index += 1) {
      rowRatio += normalizedRatios[index];
      final count = index - rowStart + 1;
      final projectedWidth =
          rowRatio * targetRowHeight + spacing * math.max(0, count - 1);
      if (projectedWidth >= availableWidth) {
        finishRow(index + 1, last: false);
      }
    }
    finishRow(normalizedRatios.length, last: true);

    return JustifiedGalleryLayout(
      rows: rows,
      contentHeight: rows.isEmpty ? 0 : offset - spacing,
    );
  }

  JustifiedGalleryRow? rowForItem(int index) {
    for (final row in rows) {
      if (row.items.first.index <= index && row.items.last.index >= index) {
        return row;
      }
    }
    return null;
  }
}

class JustifiedGalleryRow {
  const JustifiedGalleryRow({
    required this.items,
    required this.height,
    required this.offset,
  });

  final List<JustifiedGalleryItem> items;
  final double height;
  final double offset;
}

class JustifiedGalleryItem {
  const JustifiedGalleryItem({required this.index, required this.width});

  final int index;
  final double width;
}

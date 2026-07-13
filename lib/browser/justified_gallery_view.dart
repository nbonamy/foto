import 'package:flutter/material.dart';

import 'justified_layout.dart';

typedef JustifiedGalleryItemBuilder = Widget Function(
  BuildContext context,
  int itemIndex,
);

class JustifiedGalleryView extends StatelessWidget {
  const JustifiedGalleryView({
    super.key,
    required this.layout,
    required this.itemBuilder,
    this.controller,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 8,
  });

  final JustifiedGalleryLayout layout;
  final JustifiedGalleryItemBuilder itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: layout.rows.length,
      itemBuilder: (context, rowIndex) {
        final row = layout.rows[rowIndex];
        return Padding(
          padding: EdgeInsets.only(
            bottom: rowIndex == layout.rows.length - 1 ? 0 : spacing,
          ),
          child: SizedBox(
            height: row.height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < row.items.length; index += 1) ...[
                  if (index > 0) SizedBox(width: spacing),
                  SizedBox(
                    width: row.items[index].width,
                    child: itemBuilder(context, row.items[index].index),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/justified_gallery_view.dart';
import 'package:foto/browser/justified_layout.dart';

void main() {
  testWidgets('large galleries build only visible rows', (tester) async {
    final layout = JustifiedGalleryLayout.compute(
      aspectRatios: List.generate(
        10000,
        (index) => 0.6 + (index % 17) / 10,
      ),
      availableWidth: 768,
    );
    final builtItems = <int>{};

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: JustifiedGalleryView(
            layout: layout,
            itemBuilder: (context, index) {
              builtItems.add(index);
              return ColoredBox(
                key: ValueKey(index),
                color: Colors.blue,
              );
            },
          ),
        ),
      ),
    );

    expect(builtItems.length, lessThan(100));
    expect(find.byKey(const ValueKey(0)), findsOneWidget);
    expect(find.byKey(const ValueKey(9999)), findsNothing);

    await tester.drag(find.byType(Scrollable), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(builtItems.length, lessThan(200));
    expect(find.byKey(const ValueKey(9999)), findsNothing);
  });
}

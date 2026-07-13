import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/components/theme.dart';
import 'package:foto/components/toolbar.dart';

void main() {
  testWidgets('toolbar button exposes its tooltip and invokes its action',
      (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FotoTheme.light,
        home: Scaffold(
          body: FotoToolbar(
            title: 'Pictures',
            actions: [
              FotoToolbarButton(
                icon: Icons.info_outline,
                tooltip: 'Toggle Inspector',
                onPressed: () => presses += 1,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Pictures'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.info_outline));
    expect(presses, 1);

    await tester.longPress(find.byIcon(Icons.info_outline));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Toggle Inspector'), findsOneWidget);
  });

  testWidgets('selected toolbar button uses semantic selected state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FotoTheme.dark,
        home: const Scaffold(
          body: FotoToolbarButton(
            icon: Icons.folder_outlined,
            tooltip: 'Folders',
            selected: true,
            onPressed: null,
          ),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.isSelected, isTrue);
  });
}

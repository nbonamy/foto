import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/compare/compare_view.dart';
import 'package:foto/components/theme.dart';
import 'package:foto/components/toolbar.dart';
import 'package:foto/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late List<String> images;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('foto-compare-');
    final bytes = await File('assets/img/foto.png').readAsBytes();
    images = [];
    for (var index = 0; index < 4; index += 1) {
      final file =
          await File('${directory.path}/$index.png').writeAsBytes(bytes);
      images.add(file.path);
    }
  });

  tearDown(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await directory.delete(recursive: true);
  });

  Widget harness(List<String> paths, {VoidCallback? close}) {
    return MaterialApp(
      theme: FotoTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SizedBox(
        width: 1000,
        height: 700,
        child: CompareView(images: paths, close: close ?? () {}),
      ),
    );
  }

  testWidgets('two photos use equal side-by-side panes', (tester) async {
    await tester.pumpWidget(harness(images.take(2).toList()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('compare-layout-2')), findsOneWidget);
    final first = tester.getRect(find.byKey(const ValueKey('compare-pane-0')));
    final second = tester.getRect(find.byKey(const ValueKey('compare-pane-1')));
    expect(first.width, closeTo(second.width, 0.1));
    expect(first.top, closeTo(second.top, 0.1));
  });

  testWidgets('three photos give the source a wide leading pane',
      (tester) async {
    await tester.pumpWidget(harness(images.take(3).toList()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('compare-layout-3')), findsOneWidget);
    final source = tester.getRect(find.byKey(const ValueKey('compare-pane-0')));
    final second = tester.getRect(find.byKey(const ValueKey('compare-pane-1')));
    final third = tester.getRect(find.byKey(const ValueKey('compare-pane-2')));
    expect(source.width, greaterThan(second.width));
    expect(second.width, closeTo(third.width, 0.1));
    expect(second.top, closeTo(third.top, 0.1));
    expect(second.top, greaterThan(source.bottom));
  });

  testWidgets('four photos use a balanced two-by-two grid', (tester) async {
    await tester.pumpWidget(harness(images));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('compare-layout-4')), findsOneWidget);
    final first = tester.getRect(find.byKey(const ValueKey('compare-pane-0')));
    final second = tester.getRect(find.byKey(const ValueKey('compare-pane-1')));
    final third = tester.getRect(find.byKey(const ValueKey('compare-pane-2')));
    expect(first.width, closeTo(second.width, 0.1));
    expect(first.width, closeTo(third.width, 0.1));
    expect(first.top, closeTo(second.top, 0.1));
    expect(third.top, greaterThan(first.bottom));
  });

  testWidgets('sync control is selected by default and can be disabled',
      (tester) async {
    await tester.pumpWidget(harness(images.take(2).toList()));
    await tester.pump(const Duration(milliseconds: 300));

    FotoToolbarButton syncButton() => tester.widget<FotoToolbarButton>(
          find.byKey(const ValueKey('compare-sync')),
        );
    expect(syncButton().selected, isTrue);

    await tester.tap(find.byKey(const ValueKey('compare-sync')));
    await tester.pump();

    expect(syncButton().selected, isFalse);
  });

  testWidgets('Escape closes comparison', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(
      harness(images.take(2).toList(), close: () => closeCount += 1),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(closeCount, 1);
  });
}

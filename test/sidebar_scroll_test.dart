import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/sidebar.dart';
import 'package:foto/browser/tree.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:foto/model/favorites.dart';
import 'package:foto/model/history.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('favorites delegate scrolling to the enclosing sidebar',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final favorites = FavoritesModel();
    for (var index = 0; index < 30; index += 1) {
      favorites.add('/tmp/foto-favorite-$index');
    }
    final history = HistoryModel()..reset('/tmp/foto-favorite-0');
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FavoritesModel>.value(value: favorites),
          ChangeNotifierProvider<HistoryModel>.value(value: history),
        ],
        child: MacosApp(
          scrollBehavior: const _MacosTestScrollBehavior(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 250,
            height: 400,
            child: BrowserSidebar(
              scrollController: scrollController,
              navigateToFolder: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final sidebarScrollView = find.byWidgetPredicate(
      (widget) =>
          widget is CustomScrollView && widget.controller == scrollController,
    );
    expect(sidebarScrollView, findsOneWidget);
    expect(
      tester.widget<CustomScrollView>(sidebarScrollView).physics,
      isNull,
    );
    final resolvedPhysics = scrollController.position.physics;
    expect(resolvedPhysics, isA<BouncingScrollPhysics>());
    expect(
      (resolvedPhysics as BouncingScrollPhysics).decelerationRate,
      ScrollDecelerationRate.fast,
    );
    expect(find.byType(FavoriteShortcut), findsWidgets);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    final maxScrollExtent = scrollController.position.maxScrollExtent;
    expect(maxScrollExtent, greaterThan(0));

    for (var step = 1; step <= 4; step += 1) {
      scrollController.jumpTo(maxScrollExtent * step / 4);
      await tester.pump();
      expect(
        scrollController.position.maxScrollExtent,
        closeTo(maxScrollExtent, 0.01),
      );
    }

    expect(scrollController.offset, greaterThan(0));
  });

  testWidgets('favorite shortcuts navigate without expandable trees',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final favorites = FavoritesModel()..add('/tmp/foto-shortcut');
    final history = HistoryModel()..reset('/tmp/foto-shortcut/nested');
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    String? navigatedPath;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FavoritesModel>.value(value: favorites),
          ChangeNotifierProvider<HistoryModel>.value(value: history),
        ],
        child: MacosApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 250,
            height: 400,
            child: BrowserSidebar(
              scrollController: scrollController,
              navigateToFolder: (path) => navigatedPath = path,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FavoriteShortcut), findsOneWidget);
    expect(
      tester.widget<FavoriteShortcut>(find.byType(FavoriteShortcut)).selected,
      isTrue,
    );
    expect(
      find.descendant(
        of: find.byType(FavoriteShortcut),
        matching: find.byType(BrowserTree),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(FavoriteShortcut),
        matching: find.byIcon(Icons.keyboard_arrow_right),
      ),
      findsNothing,
    );

    await tester.tap(find.byType(FavoriteShortcut));
    await tester.pump();

    expect(navigatedPath, '/tmp/foto-shortcut');
  });

  testWidgets('expanded trees have an exact extent and virtualize rows',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final root = Directory.systemTemp.createTempSync('foto-tree-');
    addTearDown(() => root.deleteSync(recursive: true));
    for (var index = 0; index < 200; index += 1) {
      Directory('${root.path}/folder-${index.toString().padLeft(3, '0')}')
          .createSync();
    }

    final favorites = FavoritesModel();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesModel>.value(
        value: favorites,
        child: MacosApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: SizedBox(
              width: 250,
              height: 210,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  BrowserTree(
                    root: root.path,
                    title: 'Root',
                    onUpdate: (_, __) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.keyboard_arrow_right));
    await tester.pump();
    for (var attempt = 0;
        attempt < 50 && scrollController.position.maxScrollExtent == 0;
        attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    final maxScrollExtent = scrollController.position.maxScrollExtent;
    expect(
      maxScrollExtent,
      closeTo(201 * BrowserTree.rowExtent - 210, 0.01),
    );
    expect(find.byType(SliverFixedExtentList), findsOneWidget);
    expect(find.byType(Text).evaluate().length, lessThan(80));

    for (var step = 1; step <= 4; step += 1) {
      scrollController.jumpTo(maxScrollExtent * step / 4);
      await tester.pump();
      expect(
        scrollController.position.maxScrollExtent,
        closeTo(maxScrollExtent, 0.01),
      );
      expect(find.byType(Text).evaluate().length, lessThan(80));
    }
  });
}

class _MacosTestScrollBehavior extends MacosScrollBehavior {
  const _MacosTestScrollBehavior();

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.macOS;
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/sidebar.dart';
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

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SliverReorderableList), findsOneWidget);
    expect(find.byType(ReorderableListView), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BrowserSidebar),
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
    expect(scrollController.position.maxScrollExtent, greaterThan(0));

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();

    expect(scrollController.offset, greaterThan(0));
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:foto/model/menu_actions.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/viewer/viewer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Preferences preferences;
  late StreamController<MenuAction> menuActions;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = Preferences();
    await preferences.init();
    menuActions = StreamController<MenuAction>.broadcast();
  });

  tearDown(() async {
    await menuActions.close();
  });

  Widget viewer({
    required List<String> images,
    required int start,
    required void Function({String? current, bool? quit}) onExit,
  }) {
    return ChangeNotifierProvider<Preferences>.value(
      value: preferences,
      child: MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImageViewer(
          images: images,
          start: start,
          menuActionStream: menuActions.stream,
          exit: onExit,
        ),
      ),
    );
  }

  testWidgets('empty input exits once without indexing the list',
      (tester) async {
    var exitCount = 0;
    await tester.pumpWidget(viewer(
      images: const <String>[],
      start: -1,
      onExit: ({current, quit}) {
        exitCount += 1;
        expect(current, isNull);
        expect(quit, isFalse);
      },
    ));

    await tester.pump();
    await tester.pump();

    expect(exitCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('out-of-range start index is clamped to the last image',
      (tester) async {
    await tester.pumpWidget(viewer(
      images: const <String>['/missing-first.jpg', '/missing-last.jpg'],
      start: 99,
      onExit: ({current, quit}) {},
    ));
    await tester.pump();

    expect(find.text('/missing-last.jpg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

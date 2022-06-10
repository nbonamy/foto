import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'components/theme.dart';
import 'home.dart';
import 'model/favorites.dart';
import 'model/history.dart';
import 'model/preferences.dart';
import 'model/selection.dart';
import 'utils/platform_keyboard.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    //size: rc.size,
    //center: true,
    backgroundColor: Colors.black,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  // load some stuff
  Preferences preferences = Preferences();
  HistoryModel historyModel = HistoryModel();
  FavoritesModel favoritesModel = FavoritesModel();
  await preferences.init();
  await historyModel.init();
  await favoritesModel.init();

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    Rect rc = preferences.windowBounds;
    await windowManager.setBounds(rc);
    await windowManager.show();
    await windowManager.focus();

    runApp(FotoApp(
      args: args,
      preferences: preferences,
      historyModel: historyModel,
      favoritesModel: favoritesModel,
    ));
  });
}

class FotoApp extends StatelessWidget {
  final List<String> args;
  final Preferences preferences;
  final HistoryModel historyModel;
  final FavoritesModel favoritesModel;

  const FotoApp({
    super.key,
    required this.args,
    required this.preferences,
    required this.historyModel,
    required this.favoritesModel,
  });

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppTheme(),
        ),
        ChangeNotifierProvider(
          create: (_) => preferences,
        ),
        ChangeNotifierProvider(
          create: (_) => historyModel,
        ),
        ChangeNotifierProvider(
          create: (_) => favoritesModel,
        ),
        ChangeNotifierProvider(
          create: (_) => SelectionModel(),
        )
      ],
      builder: (context, _) {
        final appTheme = context.watch<AppTheme>();
        return MacosApp(
          title: 'foto',
          theme: MacosThemeData.light(),
          darkTheme: MacosThemeData.dark(),
          themeMode: appTheme.mode,
          debugShowCheckedModeBanner: false,
          color: Colors.black,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('fr', ''),
          ],
          home: Home(args: args),
        );
      },
    );
  }

  // ignore: unused_element
  PlatformMenuItem _menuItem(
    String label,
    LogicalKeyboardKey key,
  ) {
    return PlatformMenuItem(
      label: label,
      shortcut: PlatformKeyboard.commandActivator(key),
      onSelected: () {
        debugPrint(FocusManager.instance.primaryFocus?.debugLabel);
      },
    );
  }
}

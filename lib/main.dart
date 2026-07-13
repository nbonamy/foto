import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_size_getter_heic/image_size_getter_heic.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/app_localizations.dart';

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

  WindowOptions windowOptions = const WindowOptions(
    //size: rc.size,
    //center: true,
    //backgroundColor: Colors.white,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  // init image size getter plugins
  ImageSizeGetter.registerDecoder(HeicDecoder());

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
        final themeMode = context.select<Preferences, ThemeMode>(
          (preferences) => preferences.themeMode,
        );
        return MaterialApp(
          title: 'foto',
          theme: FotoTheme.light,
          darkTheme: FotoTheme.dark,
          themeMode: themeMode,
          scrollBehavior: const FotoScrollBehavior(),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            return MacosTheme(
              data: brightness == Brightness.dark
                  ? MacosThemeData.dark()
                  : MacosThemeData.light(),
              child: child!,
            );
          },
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

import 'package:flutter/services.dart';
import 'package:foto/model/favorites.dart';
import 'package:foto/model/history.dart';
import 'package:foto/utils/platform_keyboard.dart';
import 'package:foto/utils/preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:foto/home.dart';
import 'package:foto/utils/theme.dart';

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
  HistoryModel historyModel = HistoryModel();
  FavoritesModel favoritesModel = FavoritesModel();
  await historyModel.init();
  await favoritesModel.init();

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    Rect rc = await Preferences.getWindowBounds();
    await windowManager.setBounds(rc);
    await windowManager.show();
    await windowManager.focus();

    runApp(FotoApp(
      args: args,
      historyModel: historyModel,
      favoritesModel: favoritesModel,
    ));
  });
}

class FotoApp extends StatelessWidget {
  final List<String> args;
  final HistoryModel historyModel;
  final FavoritesModel favoritesModel;
  const FotoApp({
    super.key,
    required this.args,
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
          create: (_) => historyModel,
        ),
        ChangeNotifierProvider(
          create: (_) => favoritesModel,
        ),
      ],
      builder: (context, _) {
        final appTheme = context.watch<AppTheme>();
        return MacosApp(
          title: 'foto',
          theme: MacosThemeData.dark(),
          darkTheme: MacosThemeData.dark(),
          themeMode: appTheme.mode,
          debugShowCheckedModeBanner: false,
          color: Colors.black,
          home: PlatformMenuBar(
            menus: const [
              PlatformMenu(
                label: 'foto',
                menus: [
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.about,
                  ),
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.quit,
                  ),
                ],
              ),
              PlatformMenu(
                label: 'Edit',
                menus: [
                  //_menuItem('Copy', LogicalKeyboardKey.keyC),
                  //_menuItem('Paste', LogicalKeyboardKey.keyV),
                ],
              ),
              PlatformMenu(
                label: 'View',
                menus: [
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.toggleFullScreen,
                  ),
                ],
              ),
              PlatformMenu(
                label: 'Window',
                menus: [
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.minimizeWindow,
                  ),
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.zoomWindow,
                  ),
                ],
              ),
            ],
            body: Home(args: args),
          ),
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

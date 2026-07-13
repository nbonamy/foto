import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../components/theme.dart';
import '../components/toolbar.dart';
import '../components/window_shell.dart';
import '../model/menu_actions.dart';
import '../model/preferences.dart';
import '../utils/database.dart';
import '../utils/utils.dart';
import 'gallery.dart';
import 'inspector.dart';

class BrowserContent extends StatefulWidget {
  final MediaDb mediaDb;
  final String path;
  final bool canNavigateBack;
  final Function navigateToFolder;
  final Function viewImages;
  final MenuActionStream menuActionStream;
  final FocusNode galleryFocusNode;
  final List<String>? initialSelection;
  final bool showSidebar;
  final VoidCallback toggleSidebar;

  const BrowserContent({
    super.key,
    required this.mediaDb,
    required this.path,
    required this.canNavigateBack,
    required this.menuActionStream,
    required this.galleryFocusNode,
    required this.showSidebar,
    required this.toggleSidebar,
    required this.navigateToFolder,
    required this.viewImages,
    this.initialSelection,
  });

  @override
  State<BrowserContent> createState() => _BrowserContentState();
}

class _BrowserContentState extends State<BrowserContent> with MenuHandler {
  @override
  void initState() {
    initMenuSubscription(widget.menuActionStream);
    super.initState();
  }

  @override
  void dispose() {
    cancelMenuSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Preferences>(
      builder: (_, prefs, __) {
        final palette = FotoPalette.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildToolbar(),
            Expanded(
              child: FotoSplitView(
                trailing: prefs.showInspector
                    ? ColoredBox(
                        color: palette.sidebarSurface,
                        child: const Inspector(),
                      )
                    : null,
                child: ColoredBox(
                  color: palette.canvas,
                  child: ImageGallery(
                    path: widget.path,
                    mediaDb: widget.mediaDb,
                    navigatorContext: context,
                    executeItem: executeItem,
                    menuActionStream: widget.menuActionStream,
                    initialSelection: widget.initialSelection,
                    focusNode: widget.galleryFocusNode,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void onMenuAction(MenuAction action) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    switch (action) {
      case MenuAction.viewInspector:
        _toggleInspector();
        break;
      default:
        break;
    }
  }

  void executeItem({
    String? folder,
    List<String>? images,
    int? index,
  }) {
    if (folder != null) {
      widget.navigateToFolder(folder);
    } else if (images != null && index != null) {
      widget.viewImages(images, index);
    }
  }

  Widget buildToolbar() {
    Preferences prefs = Preferences.of(context);
    AppLocalizations t = AppLocalizations.of(context)!;
    return FotoToolbar(
      title: Utils.pathTitle(widget.path) ?? '',
      leading: widget.canNavigateBack
          ? FotoToolbarButton(
              icon: CupertinoIcons.back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => executeItem(folder: '..'),
            )
          : null,
      actions: [
        FotoToolbarButton(
          icon: CupertinoIcons.sidebar_left,
          onPressed: widget.toggleSidebar,
          tooltip: t.toolbarToggleSidebar,
          selected: widget.showSidebar,
        ),
        FotoToolbarButton(
          icon: CupertinoIcons.folder,
          onPressed: _toggleShowFolders,
          tooltip: t.toolbarToggleFolders,
          selected: prefs.showFolders,
        ),
        FotoToolbarButton(
          icon: CupertinoIcons.info_circle,
          onPressed: _toggleInspector,
          tooltip: t.toolbarToggleInspector,
          selected: prefs.showInspector,
        ),
        SizedBox.square(
          dimension: 34,
          child: PopupMenuButton<_SortAction>(
            tooltip: t.sortTitle,
            padding: EdgeInsets.zero,
            iconSize: 17,
            icon: const Icon(CupertinoIcons.sort_down_circle),
            onSelected: _applySortAction,
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: _SortAction.alphabetical,
                checked: prefs.sortCriteria == SortCriteria.alphabetical,
                child: Text(t.sortCriteriaAlphabetical),
              ),
              CheckedPopupMenuItem(
                value: _SortAction.chronological,
                checked: prefs.sortCriteria == SortCriteria.chronological,
                child: Text(t.sortCriteriaChronological),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: _SortAction.reverse,
                checked: prefs.sortReversed,
                child: Text(t.sortOrderReverse),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _applySortAction(_SortAction action) {
    switch (action) {
      case _SortAction.alphabetical:
        _setSortCriteria(SortCriteria.alphabetical);
      case _SortAction.chronological:
        _setSortCriteria(SortCriteria.chronological);
      case _SortAction.reverse:
        _toggleSortOrder();
    }
  }

  void _setSortCriteria(SortCriteria sortCriteria) {
    Preferences prefs = Preferences.of(context);
    prefs.sortCriteria = sortCriteria;
  }

  void _toggleSortOrder() {
    Preferences prefs = Preferences.of(context);
    prefs.sortReversed = !prefs.sortReversed;
  }

  void _toggleShowFolders() {
    Preferences prefs = Preferences.of(context);
    prefs.showFolders = !prefs.showFolders;
  }

  void _toggleInspector() {
    Preferences prefs = Preferences.of(context);
    prefs.showInspector = !prefs.showInspector;
  }
}

enum _SortAction {
  alphabetical,
  chronological,
  reverse,
}

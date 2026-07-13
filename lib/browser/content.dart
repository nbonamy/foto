import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

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

  const BrowserContent({
    super.key,
    required this.mediaDb,
    required this.path,
    required this.canNavigateBack,
    required this.menuActionStream,
    required this.galleryFocusNode,
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
        // start with content area
        List<Widget> widgets = [
          ContentArea(
            builder: (context, scrollController) {
              return ImageGallery(
                path: widget.path,
                mediaDb: widget.mediaDb,
                navigatorContext: context,
                executeItem: executeItem,
                scrollController: scrollController,
                menuActionStream: widget.menuActionStream,
                initialSelection: widget.initialSelection,
                focusNode: widget.galleryFocusNode,
              );
            },
          )
        ];

        // resizable panel depends on prefs
        if (prefs.showInspector) {
          widgets.add(
            ResizablePane(
              minSize: 180,
              startSize: 250,
              windowBreakpoint: 700,
              resizableSide: ResizableSide.left,
              builder: (_, __) => const Inspector(),
            ),
          );
        }

        // done
        return MacosOverlayFilter(
          borderRadius: BorderRadius.zero,
          child: MacosScaffold(
            toolBar: buildToolbar(),
            children: widgets,
          ),
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

  ToolBar buildToolbar() {
    const String tickOnPrefix = '✓';
    const String tickOffPrefix = '   ';
    Preferences prefs = Preferences.of(context);
    AppLocalizations t = AppLocalizations.of(context)!;
    return ToolBar(
      title: Text(
        Utils.pathTitle(widget.path) ?? '',
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      titleWidth: 256.0,
      leading: widget.canNavigateBack
          ? MacosBackButton(
              onPressed: () => executeItem(folder: '..'),
              fillColor: Colors.transparent,
            )
          : null,
      actions: [
        ToolBarIconButton(
          icon: const MacosIcon(CupertinoIcons.sidebar_left),
          onPressed: _toggleSidebar,
          label: t.toolbarToggleSidebar,
          showLabel: false,
        ),
        ToolBarIconButton(
          icon: const MacosIcon(CupertinoIcons.folder),
          onPressed: _toggleShowFolders,
          label: t.toolbarToggleFolders,
          showLabel: false,
        ),
        ToolBarIconButton(
          icon: const MacosIcon(CupertinoIcons.info_circle),
          onPressed: _toggleInspector,
          label: t.toolbarToggleInspector,
          showLabel: false,
        ),
        ToolBarPullDownButton(
          label: t.sortTitle,
          icon: CupertinoIcons.sort_down_circle,
          tooltipMessage: t.sortTitle,
          items: [
            MacosPulldownMenuItem(
              label: t.sortCriteriaAlphabetical,
              title: Text(
                  '${(prefs.sortCriteria == SortCriteria.alphabetical) ? tickOnPrefix : tickOffPrefix} ${t.sortCriteriaAlphabetical}'),
              onTap: () => _setSortCriteria(SortCriteria.alphabetical),
            ),
            MacosPulldownMenuItem(
              label: t.sortCriteriaChronological,
              title: Text(
                  '${(prefs.sortCriteria == SortCriteria.chronological) ? tickOnPrefix : tickOffPrefix} ${t.sortCriteriaChronological}'),
              onTap: () => _setSortCriteria(SortCriteria.chronological),
            ),
            const MacosPulldownMenuDivider(),
            MacosPulldownMenuItem(
              label: t.sortOrderReverse,
              title: Text(
                  '${prefs.sortReversed ? tickOnPrefix : tickOffPrefix} ${t.sortOrderReverse}'),
              onTap: _toggleSortOrder,
            ),
          ],
        ),
      ],
    );
  }

  void _setSortCriteria(SortCriteria sortCriteria) {
    Preferences prefs = Preferences.of(context);
    prefs.sortCriteria = sortCriteria;
  }

  void _toggleSortOrder() {
    Preferences prefs = Preferences.of(context);
    prefs.sortReversed = !prefs.sortReversed;
  }

  void _toggleSidebar() {
    MacosWindowScope.of(context).toggleSidebar();
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

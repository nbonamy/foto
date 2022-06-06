import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:foto/browser/inspector.dart';
import 'package:foto/model/menu_actions.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/utils/utils.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'gallery.dart';

class BrowserContent extends StatefulWidget {
  final String path;
  final bool canNavigateBack;
  final Function navigateToFolder;
  final Function viewImages;
  final MenuActionStream menuActionStream;
  final List<String>? initialSelection;

  const BrowserContent({
    Key? key,
    required this.path,
    required this.canNavigateBack,
    required this.menuActionStream,
    required this.navigateToFolder,
    required this.viewImages,
    this.initialSelection,
  }) : super(key: key);

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
                navigatorContext: context,
                executeItem: executeItem,
                scrollController: scrollController,
                menuActionStream: widget.menuActionStream,
                initialSelection: widget.initialSelection,
              );
            },
          )
        ];

        // resizable panel depends on prefs
        if (prefs.showInspector) {
          widgets.add(
            ResizablePane(
              minWidth: 180,
              startWidth: 250,
              windowBreakpoint: 700,
              resizableSide: ResizableSide.left,
              builder: (_, __) => const Inspector(),
            ),
          );
        }

        // done
        return MacosScaffold(
          toolBar: buildToolbar(),
          children: widgets,
        );
      },
    );
  }

  @override
  void onMenuAction(MenuAction action) {
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
          icon: const MacosIcon(CupertinoIcons.folder),
          onPressed: _toggleShowFolders,
          label: AppLocalizations.of(context)!.toolbarToggleFolders,
          showLabel: true,
        ),
        ToolBarIconButton(
          icon: const MacosIcon(CupertinoIcons.info_circle),
          onPressed: _toggleInspector,
          label: AppLocalizations.of(context)!.toolbarToggleInspector,
          showLabel: true,
        ),
        ToolBarPullDownButton(
          label: AppLocalizations.of(context)!.sortTitle,
          icon: CupertinoIcons.sort_down_circle,
          tooltipMessage: AppLocalizations.of(context)!.sortTitle,
          items: [
            MacosPulldownMenuItem(
              label: AppLocalizations.of(context)!.sortCriteriaAlphabetical,
              title: Text(
                  '${(prefs.sortCriteria == SortCriteria.alphabetical) ? tickOnPrefix : tickOffPrefix} Sort Alphabetical'),
              onTap: () => _setSortCriteria(SortCriteria.alphabetical),
            ),
            MacosPulldownMenuItem(
              label: AppLocalizations.of(context)!.sortCriteriaChronological,
              title: Text(
                  '${(prefs.sortCriteria == SortCriteria.chronological) ? tickOnPrefix : tickOffPrefix} Sort Chronological'),
              onTap: () => _setSortCriteria(SortCriteria.chronological),
            ),
            const MacosPulldownMenuDivider(),
            MacosPulldownMenuItem(
              label: AppLocalizations.of(context)!.sortOrderReverse,
              title: Text(
                  '${prefs.sortReversed ? tickOnPrefix : tickOffPrefix} Reverse Order'),
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
    prefs.notifyListeners();
    setState(() {});
  }

  void _toggleSortOrder() {
    Preferences prefs = Preferences.of(context);
    prefs.sortReversed = !prefs.sortReversed;
    prefs.notifyListeners();
    setState(() {});
  }

  void _toggleShowFolders() {
    Preferences prefs = Preferences.of(context);
    prefs.showFolders = !prefs.showFolders;
    prefs.notifyListeners();
    setState(() {});
  }

  void _toggleInspector() {
    Preferences prefs = Preferences.of(context);
    prefs.showInspector = !prefs.showInspector;
    prefs.notifyListeners();
    setState(() {});
  }
}

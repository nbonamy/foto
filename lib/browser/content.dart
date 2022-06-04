import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:foto/model/menu_actions.dart';
import 'package:foto/model/preferences.dart';
import 'package:foto/utils/utils.dart';
import 'package:macos_ui/macos_ui.dart';

import 'gallery.dart';

class BrowserContent extends StatefulWidget {
  final String path;
  final bool canNavigateBack;
  final Function navigateToFolder;
  final Function viewImages;
  final MenuActionStream menuActionStream;

  const BrowserContent({
    Key? key,
    required this.path,
    required this.canNavigateBack,
    required this.menuActionStream,
    required this.navigateToFolder,
    required this.viewImages,
  }) : super(key: key);

  @override
  State<BrowserContent> createState() => _BrowserContentState();
}

class _BrowserContentState extends State<BrowserContent> {
  @override
  Widget build(BuildContext context) {
    return MacosScaffold(
      toolBar: buildToolbar(),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return ImageGallery(
              path: widget.path,
              navigatorContext: context,
              executeItem: executeItem,
              scrollController: scrollController,
              menuActionStream: widget.menuActionStream,
            );
          },
        ),
      ],
    );
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
          icon: MacosIcon(prefs.showFolders
              ? CupertinoIcons.folder
              : CupertinoIcons.folder_fill),
          onPressed: () {
            prefs.showFolders = !prefs.showFolders;
            prefs.notifyListeners();
            setState(() {});
          },
          label: prefs.showFolders ? 'Hide Folders' : 'Show Folders',
          showLabel: true,
        ),
        ToolBarPullDownButton(
          label: 'Actions',
          icon: CupertinoIcons.sort_down_circle,
          tooltipMessage: 'Sort',
          items: [
            MacosPulldownMenuItem(
              label: 'Alphabetical',
              title: Text(
                  '${(prefs.sortType == SortType.alphabetical) ? tickOnPrefix : tickOffPrefix} Sort Alphabetical'),
              onTap: () {
                prefs.sortType = SortType.alphabetical;
                prefs.notifyListeners();
                setState(() {});
              },
            ),
            MacosPulldownMenuItem(
              label: 'Chronological',
              title: Text(
                  '${(prefs.sortType == SortType.chronological) ? tickOnPrefix : tickOffPrefix} Sort Chronological'),
              onTap: () {
                prefs.sortType = SortType.chronological;
                prefs.notifyListeners();
                setState(() {});
              },
            ),
            const MacosPulldownMenuDivider(),
            MacosPulldownMenuItem(
              label: 'Reverse.',
              title: Text(
                  '${prefs.sortReversed ? tickOnPrefix : tickOffPrefix} Reverse Order'),
              onTap: () {
                prefs.sortReversed = !prefs.sortReversed;
                prefs.notifyListeners();
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }
}

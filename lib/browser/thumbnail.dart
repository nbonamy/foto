import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/utils/paths.dart';
import 'package:foto/utils/utils.dart';
import 'package:macos_ui/macos_ui.dart';

class Thumbnail extends StatefulWidget {
  static double thumbnailWidth() {
    return _ThumbnailState.thumbnailWidth;
  }

  static double thumbnailHeight() {
    return _ThumbnailState.thumbnailWidth +
        //_ThumbnailState.labelSpacing +
        _ThumbnailState.labelHeight +
        _ThumbnailState.thumbnailPadding;
  }

  static double aspectRatio() {
    return _ThumbnailState.thumbnailWidth / thumbnailHeight();
  }

  final String path;
  final bool folder;
  final bool selected;
  final bool rename;
  final Function onRenamed;

  const Thumbnail({
    super.key,
    required this.path,
    required this.folder,
    required this.selected,
    required this.rename,
    required this.onRenamed,
  });

  @override
  State<StatefulWidget> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<Thumbnail> {
  final FocusNode _focusNode = FocusNode();
  late TextEditingController _editController;

  static const double thumbnailWidth = 160;
  static const double thumbnailPadding = 8;
  static const double highlightRadius = 6;
  static const double labelSpacing = 8;
  static const double labelHeight = 44;
  static const double labelFontSize = 12;

  @override
  void initState() {
    String label = Utils.pathTitle(widget.path)!;
    _editController = TextEditingController(text: label);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant Thumbnail oldWidget) {
    if (oldWidget.rename && !widget.rename) {
      String label = Utils.pathTitle(widget.path)!;
      if (_editController.text != label) {
        widget.onRenamed(widget.path, _editController.text);
      }
      _editController.selection = const TextSelection.collapsed(offset: 0);
    } else if (!oldWidget.rename && widget.rename) {
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.lastIndexOf('.'),
      );
      _focusNode.requestFocus();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    Color highlightColor = MacosTheme.brightnessOf(context) == Brightness.dark
        ? Colors.black
        : Colors.grey.shade300;

    return SizedBox(
      width: thumbnailWidth,
      height: Thumbnail.thumbnailHeight(),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              padding: const EdgeInsets.all(thumbnailPadding),
              decoration: BoxDecoration(
                color: widget.selected ? highlightColor : Colors.transparent,
                borderRadius: BorderRadius.circular(highlightRadius),
              ),
              child: widget.folder
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                          SystemPath.getFolderNamedAsset(widget.path)),
                    )
                  : Image.file(
                      File(widget.path),
                      cacheWidth: thumbnailWidth.toInt(),
                    ),
            ),
          ),
          SizedBox(
            width: thumbnailWidth,
            child: MacosTextField(
              focusNode: _focusNode,
              maxLines: 2,
              enabled: widget.rename,
              enableSuggestions: false,
              controller: _editController,
              decoration: BoxDecoration(
                color: null,
                boxShadow: null,
                border: Border.all(
                  color: widget.rename
                      ? const Color.fromARGB(255, 147, 178, 246)
                      : Colors.transparent,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(highlightRadius),
              ),
              disabledColor: Colors.transparent,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: labelFontSize,
                //color: Colors.white,
              ),
            ),
          )
        ],
      ),
    );
  }
}

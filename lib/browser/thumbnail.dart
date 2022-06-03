import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foto/model/media.dart';
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

  final MediaItem media;
  final bool selected;
  final bool rename;
  final Function onRenamed;

  const Thumbnail({
    super.key,
    required this.media,
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
  late Key _textFieldKey;

  static const double thumbnailWidth = 160;
  static const double thumbnailPadding = 8;
  static const double highlightRadius = 6;
  //static const double labelSpacing = 8;
  static const double labelHeight = 44;
  static const double labelFontSize = 12;

  @override
  void initState() {
    _editController = TextEditingController(text: widget.media.title);
    _textFieldKey = GlobalKey();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant Thumbnail oldWidget) {
    if (oldWidget.rename && !widget.rename) {
      String label = widget.media.title;
      if (_editController.text != label) {
        widget.onRenamed(widget.media.path, _editController.text);
      }
      _editController.selection = const TextSelection.collapsed(offset: 0);
    } else if (!oldWidget.rename && widget.rename) {
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.lastIndexOf('.'),
      );
      Future.delayed(const Duration(milliseconds: 0), () {
        _focusNode.requestFocus();
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    Widget textField = _getTextField();
    if (widget.rename) {
      textField = RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: _handleRenameKeyEvent,
        child: textField,
      );
    }
    return SizedBox(
      width: thumbnailWidth,
      height: Thumbnail.thumbnailHeight(),
      child: Column(
        children: [
          _getThumbnailImage(),
          textField,
        ],
      ),
    );
  }

  Widget _getThumbnailImage() {
    Color highlightColor = MacosTheme.brightnessOf(context) == Brightness.dark
        ? Colors.black
        : Colors.grey.shade300;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(thumbnailPadding),
        decoration: BoxDecoration(
          color: widget.selected ? highlightColor : Colors.transparent,
          borderRadius: BorderRadius.circular(highlightRadius),
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.media.isFile() ? 0 : 16),
          child: widget.media.thumbnail,
        ),
      ),
    );
  }

  Widget _getTextField() {
    return SizedBox(
      width: thumbnailWidth,
      child: MacosTextField(
        key: _textFieldKey,
        focusNode: _focusNode,
        maxLines: widget.rename ? 1 : 2,
        enabled: widget.rename,
        enableSuggestions: false,
        autocorrect: false,
        controller: _editController,
        decoration: BoxDecoration(
          color: null,
          boxShadow: null,
          border: Border.all(
            color: widget.rename
                ? const Color.fromARGB(255, 147, 178, 246)
                : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(highlightRadius),
        ),
        disabledColor: widget.selected
            ? const Color.fromARGB(255, 48, 105, 202)
            : Colors.transparent,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: labelFontSize,
          color: (widget.selected && !widget.rename) ? Colors.white : null,
        ),
      ),
    );
  }

  void _handleRenameKeyEvent(RawKeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _editController.text = Utils.pathTitle(widget.media.path)!;
      widget.onRenamed(widget.media.path, null);
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      widget.onRenamed(widget.media.path, null);
    }
  }
}

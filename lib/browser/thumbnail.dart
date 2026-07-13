import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/theme.dart';
import '../model/media.dart';
import '../utils/platform_keyboard.dart';
import '../utils/utils.dart';

class Thumbnail extends StatefulWidget {
  const Thumbnail({
    super.key,
    required this.media,
    required this.selected,
    required this.rename,
    required this.onRenamed,
    this.onAspectRatioChanged,
  });

  final MediaItem media;
  final bool selected;
  final bool rename;
  final Function onRenamed;
  final ValueChanged<double>? onAspectRatioChanged;

  @override
  State<Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<Thumbnail> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'thumbnail rename');
  late final TextEditingController _editController;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  ImageProvider? _resolvedProvider;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.media.title);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvePreviewRatio();
  }

  @override
  void didUpdateWidget(covariant Thumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.path != widget.media.path) {
      _editController.text = widget.media.title;
      _resolvedProvider = null;
      _resolvePreviewRatio();
    }

    if (oldWidget.rename && !widget.rename) {
      final originalLabel = widget.media.title;
      if (_editController.text != originalLabel) {
        final renamed = widget.onRenamed(
          widget.media.path,
          _editController.text,
        );
        if (renamed != true) _editController.text = originalLabel;
      }
      _editController.selection = const TextSelection.collapsed(offset: 0);
    } else if (!oldWidget.rename && widget.rename) {
      _editController.text = widget.media.title;
      final extensionIndex = _editController.text.lastIndexOf('.');
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset:
            extensionIndex > 0 ? extensionIndex : _editController.text.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    _focusNode.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final tooltip = StringBuffer(widget.media.title);
    if (widget.media.imageSize case final imageSize?) {
      tooltip.write('\n${imageSize.width} × ${imageSize.height}');
    }
    if (widget.media.fileSize case final fileSize?) {
      tooltip.write('\n${filesize(fileSize)}');
    }

    return Tooltip(
      message: tooltip.toString(),
      child: Semantics(
        label: widget.media.title,
        image: widget.media.isFile(),
        selected: widget.selected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.elevatedSurface,
            border: Border.all(
              color: widget.selected ? palette.selectionRing : palette.divider,
              width: widget.selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.selected ? 2 : 1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreview(palette),
                  if (widget.media.isDir()) _buildFolderLabel(palette),
                  if (widget.rename) _buildRenameField(palette),
                  if (widget.selected && !widget.rename)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.selectionRing,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child:
                              Icon(Icons.check, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(FotoPalette palette) {
    final thumbnail = widget.media.thumbnail;
    if (thumbnail == null) {
      return ColoredBox(color: palette.chromeSurface);
    }
    if (widget.media.isDir()) {
      return ColoredBox(
        color: palette.chromeSurface,
        child: Center(
          child: Transform.translate(
            key: const ValueKey('folder-artwork-position'),
            offset: const Offset(0, -14),
            child: Transform.scale(
              key: const ValueKey('folder-artwork-scale'),
              scale: 0.88,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Image(
                  image: thumbnail.image,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Image(
      image: thumbnail.image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: palette.chromeSurface,
        child: Icon(
          Icons.broken_image_outlined,
          color: palette.secondaryText,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildFolderLabel(FotoPalette palette) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
        child: Text(
          widget.media.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.primaryText,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
        ),
      ),
    );
  }

  Widget _buildRenameField(FotoPalette palette) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Focus(
        onKeyEvent: _handleRenameKeyEvent,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            focusNode: _focusNode,
            controller: _editController,
            maxLines: 1,
            enableSuggestions: false,
            autocorrect: false,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.primaryText,
                ),
            decoration: InputDecoration(
              filled: true,
              fillColor: palette.elevatedSurface,
            ),
          ),
        ),
      ),
    );
  }

  void _resolvePreviewRatio() {
    if (!widget.media.isFile()) return;
    final provider = widget.media.thumbnail?.image;
    if (provider == null || identical(provider, _resolvedProvider)) return;
    _removeImageListener();
    _resolvedProvider = provider;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((imageInfo, synchronousCall) {
      final width = imageInfo.image.width;
      final height = imageInfo.image.height;
      if (width <= 0 || height <= 0) return;
      final ratio = width / height;
      final previous = widget.media.previewAspectRatio;
      if (previous != null && (previous - ratio).abs() < 0.01) return;
      widget.media.previewAspectRatio = ratio;
      widget.onAspectRatioChanged?.call(ratio);
    });
    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _imageStream = null;
    _imageStreamListener = null;
  }

  KeyEventResult _handleRenameKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (PlatformKeyboard.isEscape(event)) {
      _editController.text = Utils.pathTitle(widget.media.path)!;
      widget.onRenamed(widget.media.path, null);
      return KeyEventResult.handled;
    }
    if (PlatformKeyboard.isEnter(event)) {
      widget.onRenamed(widget.media.path, null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

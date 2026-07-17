import 'package:flutter/material.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

import '../components/theme.dart';
import '../utils/cached_thumbnail_image_provider.dart';
import 'similarity_session.dart';

Future<List<String>?> showSimilarPhotoReview(
  BuildContext context, {
  required FolderSimilaritySession session,
}) {
  return showDialog<List<String>>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => SimilarPhotoReview(
      session: session,
      onClose: () => Navigator.of(dialogContext).pop(),
      onCompare: (paths) => Navigator.of(dialogContext).pop(paths),
    ),
  );
}

class SimilarPhotoReview extends StatefulWidget {
  const SimilarPhotoReview({
    super.key,
    required this.session,
    required this.onClose,
    required this.onCompare,
  });

  final FolderSimilaritySession session;
  final VoidCallback onClose;
  final ValueChanged<List<String>> onCompare;

  @override
  State<SimilarPhotoReview> createState() => _SimilarPhotoReviewState();
}

class _SimilarPhotoReviewState extends State<SimilarPhotoReview> {
  final Set<String> _selectedCandidates = {};

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    if (widget.session.status == SimilaritySessionStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.session.start();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SimilarPhotoReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    oldWidget.session.removeListener(_sessionChanged);
    oldWidget.session.cancel();
    _selectedCandidates.clear();
    widget.session.addListener(_sessionChanged);
    if (widget.session.status == SimilaritySessionStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.session.start();
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    widget.session.cancel();
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted) return;
    final available =
        widget.session.matches.map((match) => match.item.path).toSet();
    setState(() => _selectedCandidates.removeWhere(
          (path) => !available.contains(path),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final t = AppLocalizations.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.elevatedSurface,
            border: Border.all(color: palette.divider),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 32,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, palette, t),
                Divider(height: 1, color: palette.divider),
                Expanded(child: _buildBody(context, palette, t)),
                Divider(height: 1, color: palette.divider),
                _buildFooter(context, palette, t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    FotoPalette palette,
    AppLocalizations t,
  ) {
    final session = widget.session;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            height: 84,
            child: _ReviewImage(
              key: const ValueKey('similarity-source-preview'),
              item: session.source,
              borderRadius: 13,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.similarPhotosTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  t.similarPhotosDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.secondaryText,
                      ),
                ),
                if (session.status == SimilaritySessionStatus.running) ...[
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            key: const ValueKey('similarity-progress'),
                            value: session.progress,
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t.similarPhotosScanning(
                          session.processedCount,
                          session.totalCount,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: palette.secondaryText,
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    FotoPalette palette,
    AppLocalizations t,
  ) {
    final session = widget.session;
    final matches = session.matches;
    if (matches.isEmpty && session.status != SimilaritySessionStatus.running) {
      final (icon, message) = switch (session.status) {
        SimilaritySessionStatus.failed => (
            Icons.error_outline_rounded,
            t.similarPhotosFailed
          ),
        SimilaritySessionStatus.cancelled => (
            Icons.pause_circle_outline_rounded,
            t.similarPhotosCancelled
          ),
        _ => (Icons.image_search_rounded, t.similarPhotosEmpty),
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: palette.secondaryText),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: palette.secondaryText,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      key: const ValueKey('similarity-results'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 180,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        final selected = _selectedCandidates.contains(match.item.path);
        return _SimilarityResultCard(
          match: match,
          selected: selected,
          onPressed: () => _toggleCandidate(match.item.path),
        );
      },
    );
  }

  Widget _buildFooter(
    BuildContext context,
    FotoPalette palette,
    AppLocalizations t,
  ) {
    final session = widget.session;
    final selectedCount = 1 + _selectedCandidates.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Row(
        children: [
          Text(
            t.compareSelectionCount(selectedCount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.secondaryText,
                ),
          ),
          const Spacer(),
          if (session.status == SimilaritySessionStatus.running)
            TextButton(
              onPressed: session.cancel,
              child: Text(t.similarPhotosCancel),
            )
          else if (session.status == SimilaritySessionStatus.cancelled ||
              session.status == SimilaritySessionStatus.failed)
            TextButton(
              onPressed: () {
                _selectedCandidates.clear();
                session.start();
              },
              child: Text(t.similarPhotosRetry),
            ),
          const SizedBox(width: 10),
          FilledButton.icon(
            key: const ValueKey('compare-similar-photos'),
            onPressed: _selectedCandidates.isEmpty
                ? null
                : () => widget.onCompare([
                      session.source.path,
                      ..._selectedCandidates,
                    ]),
            icon: const Icon(Icons.compare_rounded, size: 18),
            label: Text(t.comparePhotos),
          ),
        ],
      ),
    );
  }

  void _toggleCandidate(String path) {
    setState(() {
      if (!_selectedCandidates.remove(path) && _selectedCandidates.length < 3) {
        _selectedCandidates.add(path);
      }
    });
  }
}

class _SimilarityResultCard extends StatelessWidget {
  const _SimilarityResultCard({
    required this.match,
    required this.selected,
    required this.onPressed,
  });

  final SimilarityMatch match;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final t = AppLocalizations.of(context)!;
    final bandLabel = match.band == SimilarityBand.nearDuplicate
        ? t.similarityNearDuplicate
        : t.similaritySimilar;
    return Tooltip(
      message: '${p.basename(match.item.path)}\n$bandLabel',
      child: Semantics(
        button: true,
        selected: selected,
        label: p.basename(match.item.path),
        child: Material(
          color: palette.chromeSurface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: ValueKey('similarity-result-${match.item.path}'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? palette.selectionRing : palette.divider,
                  width: selected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ReviewImage(item: match.item),
                    Positioned(
                      left: 9,
                      top: 9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: match.band == SimilarityBand.nearDuplicate
                              ? palette.selectionRing
                              : const Color(0xC92B2B30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: Text(
                            bandLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: 9,
                        top: 9,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.selectionRing,
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewImage extends StatelessWidget {
  const _ReviewImage({
    super.key,
    required this.item,
    this.borderRadius = 0,
  });

  final SimilarityItem item;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: ResizeImage.resizeIfNeeded(
        null,
        480,
        CachedThumbnailImageProvider(
          path: item.path,
          modificationDate: item.modificationDate,
          fileSize: item.fileSize,
        ),
      ),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: FotoPalette.of(context).chromeSurface,
        child: Icon(
          Icons.broken_image_outlined,
          color: FotoPalette.of(context).secondaryText,
        ),
      ),
    );
    if (borderRadius == 0) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image,
    );
  }
}

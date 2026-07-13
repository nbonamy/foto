import 'package:flutter/material.dart';

import '../components/theme.dart';

class GalleryStatusView extends StatelessWidget {
  const GalleryStatusView({
    super.key,
    required this.message,
    this.loading = false,
  });

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.accent,
                ),
              )
            else
              Icon(
                Icons.photo_library_outlined,
                size: 34,
                color: palette.secondaryText,
              ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.secondaryText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

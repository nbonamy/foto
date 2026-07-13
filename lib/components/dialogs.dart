import 'package:flutter/material.dart';
import 'package:foto/l10n/app_localizations.dart';

import 'theme.dart';

typedef DialogCallback = void Function(BuildContext);
typedef PromptCallback = void Function(BuildContext, String);

class FotoDialog {
  static Future<T?> confirm<T>({
    required BuildContext context,
    String? title,
    required String text,
    String? cancelLabel,
    String? confirmLabel,
    required DialogCallback onConfirmed,
    DialogCallback? onCancel,
    bool isDestructive = false,
    Color? barrierColor,
  }) {
    final t = AppLocalizations.of(context)!;
    return showDialog<T>(
      context: context,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) {
        final palette = FotoPalette.of(dialogContext);
        return AlertDialog(
          icon: Image.asset(
            'assets/img/foto.png',
            width: 44,
            height: 44,
          ),
          title: Text(
            title ?? AppLocalizations.of(dialogContext)?.appName ?? 'foto',
            textAlign: TextAlign.center,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(text, textAlign: TextAlign.center),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => onCancel != null
                  ? onCancel(dialogContext)
                  : Navigator.of(dialogContext).pop(),
              child: Text(cancelLabel ?? t.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    isDestructive ? palette.destructive : palette.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => onConfirmed(dialogContext),
              child: Text(confirmLabel ?? t.yes),
            ),
          ],
        );
      },
    );
  }

  static Future<T?> prompt<T>({
    required BuildContext context,
    required String text,
    required String value,
    required PromptCallback onConfirmed,
    DialogCallback? onCancel,
    bool isDanger = false,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => _FotoPromptDialog(
        text: text,
        value: value,
        onConfirmed: onConfirmed,
        onCancel: onCancel,
        isDanger: isDanger,
      ),
    );
  }
}

class _FotoPromptDialog extends StatefulWidget {
  const _FotoPromptDialog({
    required this.text,
    required this.value,
    required this.onConfirmed,
    required this.onCancel,
    required this.isDanger,
  });

  final String text;
  final String value;
  final PromptCallback onConfirmed;
  final DialogCallback? onCancel;
  final bool isDanger;

  @override
  State<_FotoPromptDialog> createState() => _FotoPromptDialogState();
}

class _FotoPromptDialogState extends State<_FotoPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = FotoPalette.of(context);
    final t = AppLocalizations.of(context)!;
    void confirm() => widget.onConfirmed(context, _controller.text);
    return AlertDialog(
      title: Text(widget.text),
      content: SizedBox(
        width: 340,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 1,
          onSubmitted: (_) => confirm(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onCancel != null
              ? widget.onCancel!(context)
              : Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                widget.isDanger ? palette.destructive : palette.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: confirm,
          child: Text(t.ok),
        ),
      ],
    );
  }
}

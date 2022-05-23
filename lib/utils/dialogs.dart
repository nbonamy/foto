import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class FotoDialog {
  static Future confirm({
    required BuildContext context,
    required String text,
    required VoidCallback onConfirmed,
    VoidCallback? onCancel,
    bool isDanger = false,
  }) {
    return showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: Image.asset(
          'assets/img/foto.png',
          width: 56,
          height: 56,
        ),
        title: Text(
          'foto',
          style: MacosTheme.of(context).typography.title3,
        ),
        message: Text(
          text,
          textAlign: TextAlign.center,
          style: MacosTheme.of(context).typography.body,
        ),
        primaryButton: PushButton(
          buttonSize: ButtonSize.small,
          color: isDanger ? Colors.red : null,
          onPressed: onConfirmed,
          child: const Text('Yes'),
        ),
        secondaryButton: PushButton(
          isSecondary: true,
          buttonSize: ButtonSize.small,
          onPressed: onCancel ?? Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

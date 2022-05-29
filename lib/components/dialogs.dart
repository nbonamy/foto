import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

typedef DialogCallback = void Function(BuildContext);
typedef PromptCallback = void Function(BuildContext, String);

class FotoDialog {
  static Future confirm({
    required BuildContext context,
    required String text,
    required DialogCallback onConfirmed,
    DialogCallback? onCancel,
    bool isDanger = false,
  }) {
    return showMacosAlertDialog(
      context: context,
      builder: (context) => MacosAlertDialog(
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
          onPressed: () => onConfirmed(context),
          child: const Text('Yes'),
        ),
        secondaryButton: PushButton(
          isSecondary: true,
          buttonSize: ButtonSize.small,
          onPressed: () =>
              onCancel != null ? onCancel(context) : Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  static Future<dynamic> prompt({
    required BuildContext context,
    required String text,
    required String value,
    required PromptCallback onConfirmed,
    DialogCallback? onCancel,
    bool isDanger = false,
  }) {
    TextEditingController controller = TextEditingController(text: value);
    return showMacosSheet(
      context: context,
      builder: (context) => MacosSheet(
        child: Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 256,
            height: 256,
            child: Column(
              children: [
                Text(text),
                MacosTextField(
                  controller: controller,
                ),
                Row(
                  children: [
                    Expanded(
                      child: PushButton(
                        child: Text('Cancel'),
                        buttonSize: ButtonSize.small,
                        isSecondary: true,
                        onPressed: () => onCancel != null
                            ? onCancel(context)
                            : Navigator.of(context).pop,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: PushButton(
                        child: Text('OK'),
                        color: Colors.green,
                        buttonSize: ButtonSize.small,
                        onPressed: () =>
                            onConfirmed(context, controller.value.text),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

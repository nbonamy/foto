import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

typedef DialogCallback = void Function(BuildContext);
typedef PromptCallback = void Function(BuildContext, String);

class FotoDialog {
  static Future confirm({
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
    AppLocalizations t = AppLocalizations.of(context)!;
    return showMacosAlertDialog(
      context: context,
      barrierColor: barrierColor,
      builder: (context) => MacosAlertDialog(
        appIcon: Image.asset(
          'assets/img/foto.png',
          width: 56,
          height: 56,
        ),
        title: Text(
          title ?? AppLocalizations.of(context)?.appName ?? 'foto',
          style: MacosTheme.of(context)
              .typography
              .title3
              .copyWith(fontWeight: FontWeight.bold),
        ),
        message: Text(
          text,
          textAlign: TextAlign.center,
          style: MacosTheme.of(context).typography.callout,
        ),
        primaryButton: PushButton(
          secondary: isDestructive,
          controlSize: ControlSize.large,
          onPressed: () => onConfirmed(context),
          child: Text(confirmLabel ?? t.yes),
        ),
        secondaryButton: PushButton(
          secondary: !isDestructive,
          controlSize: ControlSize.large,
          onPressed: () => onCancel != null
              ? onCancel(context)
              : Navigator.of(context).pop(),
          child: Text(cancelLabel ?? t.cancel),
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
    AppLocalizations t = AppLocalizations.of(context)!;
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
                        controlSize: ControlSize.small,
                        secondary: true,
                        onPressed: () => onCancel != null
                            ? onCancel(context)
                            : Navigator.of(context).pop(),
                        child: Text(t.cancel),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: PushButton(
                        color: Colors.green,
                        controlSize: ControlSize.small,
                        onPressed: () =>
                            onConfirmed(context, controller.value.text),
                        child: Text(t.ok),
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

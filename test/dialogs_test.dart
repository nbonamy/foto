import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/components/dialogs.dart';
import 'package:foto/components/theme.dart';
import 'package:foto/l10n/app_localizations.dart';

void main() {
  Widget harness(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? FotoTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('confirmation dialog returns the selected result',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await FotoDialog.confirm<bool>(
                context: context,
                title: 'Remove photo?',
                text: 'This action cannot be undone.',
                cancelLabel: 'Keep',
                confirmLabel: 'Remove',
                isDestructive: true,
                onConfirmed: (dialogContext) =>
                    Navigator.of(dialogContext).pop(true),
                onCancel: (dialogContext) =>
                    Navigator.of(dialogContext).pop(false),
              );
            },
            child: const Text('Open'),
          ),
        ),
        theme: FotoTheme.dark,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Remove photo?'), findsOneWidget);
    expect(find.text('This action cannot be undone.'), findsOneWidget);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('prompt submits edited text', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => FotoDialog.prompt<void>(
              context: context,
              text: 'Rename',
              value: 'old name',
              onConfirmed: (dialogContext, value) {
                submitted = value;
                Navigator.of(dialogContext).pop();
              },
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'new name');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(submitted, 'new name');
  });
}

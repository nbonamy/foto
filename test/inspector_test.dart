import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/inspector.dart';
import 'package:foto/components/theme.dart';
import 'package:foto/l10n/app_localizations.dart';
import 'package:foto/model/selection.dart';
import 'package:foto/utils/utils.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('inspector follows selection and loads basic image metadata',
      (tester) async {
    final selection = SelectionModel();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: selection,
        child: MaterialApp(
          theme: FotoTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Inspector(
              metadataLoader: (_) async => InspectorMetadata(
                fileSize: 42,
                creationDate: DateTime.fromMillisecondsSinceEpoch(1000),
                imageSize: SizeInt(2, 3),
                exifData: const {},
              ),
            ),
          ),
        ),
      ),
    );

    selection.set(['/photos/selected.webp']);
    await tester.pump();
    expect(find.text('selected.webp'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();

    expect(find.text('2 × 3'), findsOneWidget);
    expect(find.text('Loading metadata…'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    selection.dispose();
  });
}

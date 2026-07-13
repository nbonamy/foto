import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/thumbnail.dart';
import 'package:foto/components/theme.dart';
import 'package:foto/model/media.dart';

void main() {
  MediaItem media(String path, FileSystemEntityType type) {
    return MediaItem(
      path: path,
      entityType: type,
      mediaInfoParsed: type != FileSystemEntityType.file,
      captureDateParsed: type != FileSystemEntityType.file,
      creationDate: DateTime(2024),
      modificationDate: DateTime(2024),
      thumbnail: Image.memory(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAAFElEQVR4nGP8z8Dwn4GBgYGJAQoAHgQCAf8M3aQAAAAASUVORK5CYII=',
        ),
      ),
    );
  }

  Widget harness(Widget child) {
    return MaterialApp(
      theme: FotoTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 280, height: 180, child: child),
        ),
      ),
    );
  }

  testWidgets('photo tile has no visible filename label', (tester) async {
    final photo = media('/photos/sunrise.jpg', FileSystemEntityType.file);
    await tester.pumpWidget(
      harness(
        Thumbnail(
          media: photo,
          selected: false,
          rename: false,
          onRenamed: (_, __) {},
        ),
      ),
    );

    expect(find.text('sunrise.jpg'), findsNothing);
    expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'sunrise.jpg');
  });

  testWidgets('folder tile labels large artwork without a gradient',
      (tester) async {
    final folder = media('/photos/Trips', FileSystemEntityType.directory);
    await tester.pumpWidget(
      harness(
        Thumbnail(
          media: folder,
          selected: false,
          rename: false,
          onRenamed: (_, __) {},
        ),
      ),
    );

    expect(find.text('Trips'), findsOneWidget);
    expect(find.byIcon(Icons.folder_rounded), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    final label = tester.widget<Text>(find.text('Trips'));
    expect(label.style?.color, FotoTheme.lightPalette.primaryText);
    expect(label.style?.letterSpacing, 0);
    final artworkScale = tester.widget<Transform>(
      find.byKey(const ValueKey('folder-artwork-scale')),
    );
    expect(artworkScale.transform.entry(0, 0), 0.88);
    expect(artworkScale.transform.entry(1, 1), 0.88);
    final artworkPosition = tester.widget<Transform>(
      find.byKey(const ValueKey('folder-artwork-position')),
    );
    expect(artworkPosition.transform.getTranslation().y, -14);
    final gradients = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.gradient != null);
    expect(gradients, isEmpty);
  });

  testWidgets('filename field only appears while renaming', (tester) async {
    final photo = media('/photos/sunrise.jpg', FileSystemEntityType.file);
    await tester.pumpWidget(
      harness(
        Thumbnail(
          media: photo,
          selected: true,
          rename: true,
          onRenamed: (_, __) {},
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'sunrise.jpg',
    );
  });
}

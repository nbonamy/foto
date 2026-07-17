import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/browser/photo_loupe.dart';

void main() {
  final preview = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAAFElEQVR4nGP8z8Dwn4GBgYGJAQoAHgQCAf8M3aQAAAAASUVORK5CYII=',
    ),
  );

  GalleryLoupeTarget target(String path, {Offset? position}) {
    return GalleryLoupeTarget(
      path: path,
      preview: preview,
      normalizedPosition: position ?? const Offset(0.5, 0.5),
      surfacePosition: const Offset(100, 100),
    );
  }

  test('hover stays dormant until Space is held', () {
    final controller = GalleryLoupeController();
    addTearDown(controller.dispose);

    controller.hover(target('/photos/a.jpg'));
    expect(controller.value, isNull);

    controller.setHeld(true);
    expect(controller.value?.path, '/photos/a.jpg');

    controller.hover(target('/photos/a.jpg', position: const Offset(0.8, 0.2)));
    expect(controller.value?.normalizedPosition, const Offset(0.8, 0.2));

    controller.setHeld(false);
    expect(controller.value, isNull);
  });

  test('leaving the hovered tile closes the held loupe', () {
    final controller = GalleryLoupeController()..setHeld(true);
    addTearDown(controller.dispose);

    controller.hover(target('/photos/a.jpg'));
    controller.leave('/photos/another.jpg');
    expect(controller.value?.path, '/photos/a.jpg');

    controller.leave('/photos/a.jpg');
    expect(controller.value, isNull);
  });

  test('cover geometry maps a wide image through its center crop', () {
    final left = LoupeGeometry.normalizedSourcePosition(
      localPosition: Offset.zero,
      tileSize: const Size.square(100),
      imageAspectRatio: 2,
    );
    final right = LoupeGeometry.normalizedSourcePosition(
      localPosition: const Offset(100, 100),
      tileSize: const Size.square(100),
      imageAspectRatio: 2,
    );

    expect(left.dx, closeTo(0.25, 0.0001));
    expect(left.dy, 0);
    expect(right.dx, closeTo(0.75, 0.0001));
    expect(right.dy, 1);
  });

  test('cover geometry maps a tall image through its center crop', () {
    final top = LoupeGeometry.normalizedSourcePosition(
      localPosition: Offset.zero,
      tileSize: const Size.square(100),
      imageAspectRatio: 0.5,
    );
    final bottom = LoupeGeometry.normalizedSourcePosition(
      localPosition: const Offset(100, 100),
      tileSize: const Size.square(100),
      imageAspectRatio: 0.5,
    );

    expect(top.dx, 0);
    expect(top.dy, closeTo(0.25, 0.0001));
    expect(bottom.dx, 1);
    expect(bottom.dy, closeTo(0.75, 0.0001));
  });

  test('overlay flips and clamps inside the gallery surface', () {
    expect(
      LoupeGeometry.overlayOrigin(
        pointer: const Offset(480, 380),
        surfaceSize: const Size(500, 400),
        loupeSize: 200,
      ),
      const Offset(258, 158),
    );
    expect(
      LoupeGeometry.overlayOrigin(
        pointer: const Offset(2, 2),
        surfaceSize: const Size(500, 400),
        loupeSize: 200,
      ),
      const Offset(24, 24),
    );
  });
}

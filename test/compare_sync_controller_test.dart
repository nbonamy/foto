import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/compare/compare_sync_controller.dart';

void main() {
  test('normalizes scale and pan across differently sized panes', () {
    final controller = CompareSyncController();
    addTearDown(controller.dispose);
    final first = <ComparePaneTransform>[];
    final second = <ComparePaneTransform>[];
    controller.registerPane(
      id: 0,
      fitScale: 0.5,
      viewportSize: const Size(100, 200),
      apply: first.add,
    );
    controller.registerPane(
      id: 1,
      fitScale: 0.25,
      viewportSize: const Size(200, 100),
      apply: second.add,
    );
    first.clear();
    second.clear();

    controller.updateFromPane(
      id: 0,
      scale: 1,
      position: const Offset(20, -40),
    );

    expect(first, isEmpty);
    expect(second.single.scale, 0.5);
    expect(second.single.position, const Offset(40, -20));
    expect(controller.viewport.zoom, 2);
    expect(
      controller.viewport.normalizedPosition,
      const Offset(0.2, -0.2),
    );
  });

  test('disabled synchronization leaves other panes untouched', () {
    final controller = CompareSyncController();
    addTearDown(controller.dispose);
    final second = <ComparePaneTransform>[];
    controller.registerPane(
      id: 0,
      fitScale: 0.5,
      viewportSize: const Size.square(100),
      apply: (_) {},
    );
    controller.registerPane(
      id: 1,
      fitScale: 0.5,
      viewportSize: const Size.square(100),
      apply: second.add,
    );
    second.clear();

    controller.setSynchronized(false);
    controller.updateFromPane(
      id: 0,
      scale: 1,
      position: const Offset(10, 10),
    );

    expect(second, isEmpty);
    expect(controller.viewport.zoom, 2);
  });

  test('fit and actual-pixel actions update every pane', () {
    final controller = CompareSyncController();
    addTearDown(controller.dispose);
    final applied = <int, List<ComparePaneTransform>>{
      0: [],
      1: [],
    };
    controller.registerPane(
      id: 0,
      fitScale: 0.5,
      viewportSize: const Size.square(100),
      apply: applied[0]!.add,
    );
    controller.registerPane(
      id: 1,
      fitScale: 0.25,
      viewportSize: const Size.square(100),
      apply: applied[1]!.add,
    );
    for (final values in applied.values) {
      values.clear();
    }

    controller.showActualPixels(sourcePane: 0);
    expect(applied[0]!.last.scale, 1);
    expect(applied[1]!.last.scale, 1);

    controller.fitAll();
    expect(applied[0]!.last.scale, 0.5);
    expect(applied[1]!.last.scale, 0.25);
    expect(applied[0]!.last.position, Offset.zero);
    expect(applied[1]!.last.position, Offset.zero);
  });

  test('synchronous feedback during propagation is ignored', () {
    final controller = CompareSyncController();
    addTearDown(controller.dispose);
    controller.registerPane(
      id: 0,
      fitScale: 0.5,
      viewportSize: const Size.square(100),
      apply: (_) {},
    );
    controller.registerPane(
      id: 1,
      fitScale: 0.25,
      viewportSize: const Size.square(100),
      apply: (transform) {
        controller.updateFromPane(
          id: 1,
          scale: transform.scale,
          position: transform.position,
        );
      },
    );

    controller.updateFromPane(
      id: 0,
      scale: 1,
      position: const Offset(25, 0),
    );

    expect(controller.viewport.zoom, 2);
    expect(controller.viewport.normalizedPosition, const Offset(0.25, 0));
  });
}

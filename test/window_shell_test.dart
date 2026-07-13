import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/components/theme.dart';
import 'package:foto/components/window_shell.dart';

void main() {
  Widget harness({
    required Widget child,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme ?? FotoTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('window shell keeps the sidebar as a stable wide-layout sibling',
      (tester) async {
    await tester.pumpWidget(
      harness(
        child: const FotoWindowShell(
          showSidebar: true,
          sidebar: Text('sidebar contents'),
          child: Text('gallery contents'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('foto-sidebar-region')), findsOneWidget);
    expect(find.text('sidebar contents'), findsOneWidget);
    expect(find.text('gallery contents'), findsOneWidget);

    final region = tester.widget<SizedBox>(
      find.byKey(const ValueKey('foto-sidebar-region')),
    );
    expect(region.width, 244);
  });

  testWidgets('compact window hides the sidebar without removing the gallery',
      (tester) async {
    await tester.pumpWidget(
      harness(
        child: const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            height: 400,
            child: FotoWindowShell(
              showSidebar: true,
              sidebar: Text('sidebar contents'),
              child: Text('gallery contents'),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('foto-sidebar-region')), findsNothing);
    expect(find.text('sidebar contents'), findsNothing);
    expect(find.text('gallery contents'), findsOneWidget);
  });

  testWidgets('split view resizes the inspector locally', (tester) async {
    await tester.pumpWidget(
      harness(
        child: const FotoSplitView(
          trailing: Text('inspector'),
          child: Text('gallery'),
        ),
      ),
    );

    SizedBox pane() => tester.widget<SizedBox>(
          find.byKey(const ValueKey('foto-trailing-pane')),
        );

    expect(pane().width, 280);
    await tester.drag(
      find.byKey(const ValueKey('foto-pane-resize-handle')),
      const Offset(-60, 0),
    );
    await tester.pump();
    expect(pane().width, 340);
  });

  testWidgets('compact split view overlays rather than squeezing the gallery',
      (tester) async {
    await tester.pumpWidget(
      harness(
        theme: FotoTheme.dark,
        child: const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            height: 400,
            child: FotoSplitView(
              trailing: Text('inspector'),
              child: Text('gallery'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('gallery'), findsOneWidget);
    expect(find.text('inspector'), findsOneWidget);
    expect(find.byKey(const ValueKey('foto-trailing-pane')), findsNothing);
    expect(tester.getSize(find.text('gallery')).width, greaterThan(0));
  });
}

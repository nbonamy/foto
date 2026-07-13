import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foto/components/theme.dart';

void main() {
  test('foto themes expose complete independent light and dark palettes', () {
    final light = FotoTheme.light;
    final dark = FotoTheme.dark;
    final lightPalette = light.extension<FotoPalette>();
    final darkPalette = dark.extension<FotoPalette>();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(lightPalette, isNotNull);
    expect(darkPalette, isNotNull);
    expect(lightPalette!.canvas, isNot(darkPalette!.canvas));
    expect(lightPalette.sidebarSurface, isNot(darkPalette.sidebarSurface));
    expect(lightPalette.chromeSurface, isNot(darkPalette.chromeSurface));
    expect(lightPalette.selectionRing, isNot(darkPalette.selectionRing));
    expect(light.scaffoldBackgroundColor, lightPalette.canvas);
    expect(dark.scaffoldBackgroundColor, darkPalette.canvas);
  });

  test('critical text and accent pairs meet desktop contrast targets', () {
    for (final palette in [
      FotoTheme.lightPalette,
      FotoTheme.darkPalette,
    ]) {
      expect(_contrast(palette.primaryText, palette.canvas), greaterThan(7));
      expect(
          _contrast(palette.secondaryText, palette.canvas), greaterThan(4.5));
      expect(_contrast(palette.accent, palette.canvas), greaterThan(3));
    }
  });

  testWidgets('foto scroll behavior uses fast macos bouncing physics',
      (tester) async {
    const behavior = FotoScrollBehavior();
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final physics = behavior.getScrollPhysics(capturedContext);
    expect(behavior.getPlatform(capturedContext), TargetPlatform.macOS);
    expect(physics, isA<BouncingScrollPhysics>());
    expect(
      (physics as BouncingScrollPhysics).decelerationRate,
      ScrollDecelerationRate.fast,
    );
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final darker = identical(lighter, foreground) ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

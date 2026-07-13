import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class FotoPalette extends ThemeExtension<FotoPalette> {
  const FotoPalette({
    required this.canvas,
    required this.sidebarSurface,
    required this.chromeSurface,
    required this.elevatedSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.divider,
    required this.outline,
    required this.hover,
    required this.pressed,
    required this.selectionFill,
    required this.selectionRing,
    required this.accent,
    required this.destructive,
  });

  final Color canvas;
  final Color sidebarSurface;
  final Color chromeSurface;
  final Color elevatedSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color divider;
  final Color outline;
  final Color hover;
  final Color pressed;
  final Color selectionFill;
  final Color selectionRing;
  final Color accent;
  final Color destructive;

  static FotoPalette of(BuildContext context) {
    return Theme.of(context).extension<FotoPalette>()!;
  }

  @override
  FotoPalette copyWith({
    Color? canvas,
    Color? sidebarSurface,
    Color? chromeSurface,
    Color? elevatedSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? divider,
    Color? outline,
    Color? hover,
    Color? pressed,
    Color? selectionFill,
    Color? selectionRing,
    Color? accent,
    Color? destructive,
  }) {
    return FotoPalette(
      canvas: canvas ?? this.canvas,
      sidebarSurface: sidebarSurface ?? this.sidebarSurface,
      chromeSurface: chromeSurface ?? this.chromeSurface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      divider: divider ?? this.divider,
      outline: outline ?? this.outline,
      hover: hover ?? this.hover,
      pressed: pressed ?? this.pressed,
      selectionFill: selectionFill ?? this.selectionFill,
      selectionRing: selectionRing ?? this.selectionRing,
      accent: accent ?? this.accent,
      destructive: destructive ?? this.destructive,
    );
  }

  @override
  FotoPalette lerp(covariant FotoPalette? other, double t) {
    if (other == null) return this;
    return FotoPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      sidebarSurface: Color.lerp(sidebarSurface, other.sidebarSurface, t)!,
      chromeSurface: Color.lerp(chromeSurface, other.chromeSurface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      pressed: Color.lerp(pressed, other.pressed, t)!,
      selectionFill: Color.lerp(selectionFill, other.selectionFill, t)!,
      selectionRing: Color.lerp(selectionRing, other.selectionRing, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
    );
  }
}

abstract final class FotoTheme {
  static const FotoPalette lightPalette = FotoPalette(
    canvas: Color(0xFFF6F7FA),
    sidebarSurface: Color(0xEAF0F2F8),
    chromeSurface: Color(0xE8FFFFFF),
    elevatedSurface: Color(0xFFFFFFFF),
    primaryText: Color(0xFF20222A),
    secondaryText: Color(0xFF686D7A),
    divider: Color(0x1F343844),
    outline: Color(0x33343844),
    hover: Color(0x0F5A5FD7),
    pressed: Color(0x1F5A5FD7),
    selectionFill: Color(0x1F696CFF),
    selectionRing: Color(0xFF696CFF),
    accent: Color(0xFF595CD6),
    destructive: Color(0xFFBB2D3B),
  );

  static const FotoPalette darkPalette = FotoPalette(
    canvas: Color(0xFF0F1117),
    sidebarSurface: Color(0xEB171A22),
    chromeSurface: Color(0xEA1D2029),
    elevatedSurface: Color(0xFF252933),
    primaryText: Color(0xFFF3F4F8),
    secondaryText: Color(0xFFA6AAB7),
    divider: Color(0x24E4E6EF),
    outline: Color(0x38E4E6EF),
    hover: Color(0x169B94FF),
    pressed: Color(0x2B9B94FF),
    selectionFill: Color(0x299B94FF),
    selectionRing: Color(0xFFA29CFF),
    accent: Color(0xFF9B94FF),
    destructive: Color(0xFFFF727D),
  );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        palette: lightPalette,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        palette: darkPalette,
      );

  static ThemeData _build({
    required Brightness brightness,
    required FotoPalette palette,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
    );
    final colorScheme = baseScheme.copyWith(
      primary: palette.accent,
      error: palette.destructive,
      surface: palette.elevatedSurface,
      onSurface: palette.primaryText,
      outline: palette.outline,
      outlineVariant: palette.divider,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      dividerColor: palette.divider,
      focusColor: palette.selectionFill,
      hoverColor: palette.hover,
      splashColor: Colors.transparent,
      highlightColor: palette.pressed,
      fontFamily: '.AppleSystemUIFont',
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      extensions: <ThemeExtension<dynamic>>[palette],
    );

    final textTheme = base.textTheme.apply(
      bodyColor: palette.primaryText,
      displayColor: palette.primaryText,
    );

    return base.copyWith(
      textTheme: textTheme,
      iconTheme: IconThemeData(color: palette.secondaryText, size: 18),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: palette.elevatedSurface,
          border: Border.all(color: palette.outline),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: palette.primaryText,
          fontSize: 12,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.elevatedSurface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: palette.outline)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 5),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.elevatedSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.outline),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.elevatedSurface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabledBorder: _inputBorder(palette.outline),
        focusedBorder: _inputBorder(palette.selectionRing, width: 2),
        errorBorder: _inputBorder(palette.destructive),
        focusedErrorBorder: _inputBorder(palette.destructive, width: 2),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class FotoScrollBehavior extends MaterialScrollBehavior {
  const FotoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
    );
  }

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.macOS;
}

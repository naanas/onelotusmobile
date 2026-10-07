import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/transitions.dart';

import 'ol_colors.dart';
import 'ol_tokens.dart';

export 'ol_colors.dart';
export 'ol_tokens.dart';

ThemeData buildOlTheme([OlColors c = OlColors.light]) {
  final t = OlText(c);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.brand,
        brightness: Brightness.light,
      ).copyWith(
        primary: c.brand,
        onPrimary: Colors.white,
        secondary: c.brandDeep,
        surface: c.surface,
        onSurface: c.fg,
        error: c.crit,
        outline: c.line,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: kFontBody,
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: OlPageTransitionsBuilder(),
        // iOS tetap Cupertino agar gesture geser-kembali bekerja.
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: TextTheme(
      displaySmall: t.display,
      headlineSmall: t.title,
      titleMedium: t.heading,
      bodyMedium: t.body,
      bodyLarge: t.body.copyWith(fontSize: 15),
      bodySmall: t.caption,
      labelLarge: t.button,
      labelMedium: t.fieldLabel,
      labelSmall: t.overline,
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.brand,
      selectionColor: c.brandSoft,
      selectionHandleColor: c.brand,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.toastBg,
      contentTextStyle: t.body.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: const Color(0xFF7DD3FC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OlRadius.dialog),
      ),
      titleTextStyle: t.heading.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: t.body.copyWith(color: c.muted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: c.scrim,
      showDragHandle: true,
      dragHandleColor: const Color(0xFFCDD9E3),
      dragHandleSize: const Size(40, 5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(OlRadius.sheet),
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: t.heading,
      systemOverlayStyle: OlStatusBar.dark,
    ),
  );
}

/// Gaya status bar & navigation bar. Ikon gelap di atas latar terang,
/// ikon terang di atas header hero / splash biru tua.
abstract final class OlStatusBar {
  static const dark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light, // iOS
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const light = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark, // iOS
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  /// Splash: navigation bar ikut biru tua agar layar penuh satu warna.
  static const splash = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0C4A6E),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}

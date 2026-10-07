import 'package:flutter/material.dart';

import 'ol_colors.dart';

const kFontBody = 'PlusJakartaSans';
const kFontMono = 'JetBrainsMono';

/// Spasi — grid 4dp (spec §2.4).
abstract final class OlSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Padding horizontal layar (v2 prototipe: 20).
  static const double screen = 20;

  /// Jarak antar kartu.
  static const double gap = 12;
}

/// Radius (spec D.5 / ol.css v2).
abstract final class OlRadius {
  static const double card = 20;
  static const double button = 16;
  static const double buttonSmall = 13;
  static const double input = 14;
  static const double banner = 16;
  static const double dialog = 26;
  static const double sheet = 28;
  static const double heroBottom = 28;
  static const double pill = 999;
}

/// Ukuran sentuh & komponen.
abstract final class OlSize {
  static const double minTouch = 48;
  static const double button = 52;
  static const double buttonSmall = 42;
  static const double input = 50;
  static const double fab = 56;
  static const double icon = 24;
}

/// Bayangan — kartu tanpa garis tepi, pakai `sh1` (D.5).
abstract final class OlShadow {
  static const sh1 = [
    BoxShadow(color: Color(0x0D0B1F2E), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(
      color: Color(0x240B1F2E),
      offset: Offset(0, 6),
      blurRadius: 20,
      spreadRadius: -10,
    ),
  ];
  static const sh2 = [
    BoxShadow(color: Color(0x0F0B1F2E), offset: Offset(0, 2), blurRadius: 4),
    BoxShadow(
      color: Color(0x380B1F2E),
      offset: Offset(0, 16),
      blurRadius: 32,
      spreadRadius: -16,
    ),
  ];
  static const brandButton = [
    BoxShadow(
      color: Color(0xCC0277B5),
      offset: Offset(0, 10),
      blurRadius: 20,
      spreadRadius: -12,
    ),
  ];
  static const critButton = [
    BoxShadow(
      color: Color(0xCCC0262D),
      offset: Offset(0, 10),
      blurRadius: 20,
      spreadRadius: -12,
    ),
  ];
}

/// Gerak (spec §2.5): 150–250ms, easeOutCubic. Selalu cek [reduced].
abstract final class OlMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Durasi efektif: nol bila pengguna mematikan animasi.
  static Duration of(BuildContext context, [Duration d = normal]) =>
      reduced(context) ? Duration.zero : d;
}

/// Tipografi (spec §2.3, judul layar mengikuti v2 24/800).
@immutable
class OlText {
  const OlText(this.c);

  final OlColors c;

  static const _tabular = [FontFeature.tabularFigures()];

  TextStyle get display => TextStyle(
    fontFamily: kFontBody,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.84,
    height: 1.15,
    color: c.fg,
    fontFeatures: _tabular,
  );
  TextStyle get title => TextStyle(
    fontFamily: kFontBody,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.15,
    color: c.fg,
  );
  TextStyle get heading => TextStyle(
    fontFamily: kFontBody,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.16,
    height: 1.35,
    color: c.fg,
  );
  TextStyle get body => TextStyle(
    fontFamily: kFontBody,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: c.fg,
    fontFeatures: _tabular,
  );
  TextStyle get bodyStrong => body.copyWith(fontWeight: FontWeight.w700);
  TextStyle get caption => TextStyle(
    fontFamily: kFontBody,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: c.muted,
    fontFeatures: _tabular,
  );

  /// Label seksi huruf kapital (`.lbl`).
  TextStyle get overline => TextStyle(
    fontFamily: kFontBody,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.92,
    color: c.faint,
  );
  TextStyle get fieldLabel => TextStyle(
    fontFamily: kFontBody,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: c.fg,
  );
  TextStyle get button => const TextStyle(
    fontFamily: kFontBody,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.08,
  );
  TextStyle get mono => TextStyle(
    fontFamily: kFontMono,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: c.fg,
    fontFeatures: _tabular,
  );
}

extension OlThemeContext on BuildContext {
  OlColors get ol => Theme.of(this).extension<OlColors>()!;
  OlText get olText => OlText(ol);
}

import 'package:flutter/material.dart';

/// Token warna One Lotus v2 — sumber: design/source/ol.css (`:root`) & spec §2 / D.5.
/// Layar tidak boleh memakai warna hardcode; ambil lewat `context.ol`.
@immutable
class OlColors extends ThemeExtension<OlColors> {
  const OlColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.fg,
    required this.muted,
    required this.faint,
    required this.brand,
    required this.brandHover,
    required this.brandDeep,
    required this.brandSoft,
    required this.gold,
    required this.goldSoft,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.crit,
    required this.critSoft,
    required this.toastBg,
    required this.scrim,
  });

  /// Tema terang (default aplikasi).
  static const light = OlColors(
    bg: Color(0xFFF2F5F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF3F7),
    line: Color(0xFFE4EBF1),
    fg: Color(0xFF0B1F2E),
    muted: Color(0xFF5A6E7E),
    faint: Color(0xFF8496A5),
    brand: Color(0xFF0277B5),
    brandHover: Color(0xFF0369A1),
    brandDeep: Color(0xFF0B3B5C),
    brandSoft: Color(0xFFE3F2FC),
    gold: Color(0xFFA85E05),
    goldSoft: Color(0xFFFDF3E3),
    ok: Color(0xFF127A3E),
    okSoft: Color(0xFFE1F5E8),
    warn: Color(0xFF9A4A07),
    warnSoft: Color(0xFFFFF1DC),
    crit: Color(0xFFC0262D),
    critSoft: Color(0xFFFDE8E8),
    toastBg: Color(0xFF0B1F2E),
    scrim: Color(0x80081824),
  );

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color line;
  final Color fg;
  final Color muted;
  final Color faint;
  final Color brand;
  final Color brandHover;
  final Color brandDeep;
  final Color brandSoft;
  final Color gold;
  final Color goldSoft;
  final Color ok;
  final Color okSoft;
  final Color warn;
  final Color warnSoft;
  final Color crit;
  final Color critSoft;
  final Color toastBg;
  final Color scrim;

  @override
  OlColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? line,
    Color? fg,
    Color? muted,
    Color? faint,
    Color? brand,
    Color? brandHover,
    Color? brandDeep,
    Color? brandSoft,
    Color? gold,
    Color? goldSoft,
    Color? ok,
    Color? okSoft,
    Color? warn,
    Color? warnSoft,
    Color? crit,
    Color? critSoft,
    Color? toastBg,
    Color? scrim,
  }) => OlColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    line: line ?? this.line,
    fg: fg ?? this.fg,
    muted: muted ?? this.muted,
    faint: faint ?? this.faint,
    brand: brand ?? this.brand,
    brandHover: brandHover ?? this.brandHover,
    brandDeep: brandDeep ?? this.brandDeep,
    brandSoft: brandSoft ?? this.brandSoft,
    gold: gold ?? this.gold,
    goldSoft: goldSoft ?? this.goldSoft,
    ok: ok ?? this.ok,
    okSoft: okSoft ?? this.okSoft,
    warn: warn ?? this.warn,
    warnSoft: warnSoft ?? this.warnSoft,
    crit: crit ?? this.crit,
    critSoft: critSoft ?? this.critSoft,
    toastBg: toastBg ?? this.toastBg,
    scrim: scrim ?? this.scrim,
  );

  @override
  OlColors lerp(OlColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return OlColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      line: l(line, other.line),
      fg: l(fg, other.fg),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      brand: l(brand, other.brand),
      brandHover: l(brandHover, other.brandHover),
      brandDeep: l(brandDeep, other.brandDeep),
      brandSoft: l(brandSoft, other.brandSoft),
      gold: l(gold, other.gold),
      goldSoft: l(goldSoft, other.goldSoft),
      ok: l(ok, other.ok),
      okSoft: l(okSoft, other.okSoft),
      warn: l(warn, other.warn),
      warnSoft: l(warnSoft, other.warnSoft),
      crit: l(crit, other.crit),
      critSoft: l(critSoft, other.critSoft),
      toastBg: l(toastBg, other.toastBg),
      scrim: l(scrim, other.scrim),
    );
  }
}

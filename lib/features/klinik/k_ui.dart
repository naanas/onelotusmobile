import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Kit tampilan menu staf (admin & terapis): kartu hero bergradien, statistik, seksi form berikon,
/// progres kelengkapan, pilihan pil, timeline, avatar berwarna. Semua animasi menghormati "kurangi gerakan".

// ── Warna avatar per nama ───────────────────────────────────────────────────────────────────────

/// Pasangan (latar lembut, warna isi) — dipilih stabil dari nama supaya tiap pasien mudah dibedakan.
List<(Color, Color)> _tones(OlColors c) => [
  (c.brandSoft, c.brand),
  (c.okSoft, c.ok),
  (c.goldSoft, c.gold),
  (const Color(0xFFEEEAFD), const Color(0xFF5B45C2)),
  (const Color(0xFFE0F5F4), const Color(0xFF0F766E)),
  (c.warnSoft, c.warn),
];

(Color, Color) kTone(BuildContext context, String seed) {
  final tones = _tones(context.ol);
  var h = 0;
  for (final r in seed.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  return tones[h % tones.length];
}

class KAvatar extends StatelessWidget {
  const KAvatar({super.key, required this.name, this.size = 46, this.ring = false});
  final String name;
  final double size;

  /// Cincin putih (di atas kartu hero).
  final bool ring;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = parts.first.characters.first;
    final b = parts.length > 1 ? parts.last.characters.first : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (soft, ink) = kTone(context, name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [soft, Color.lerp(soft, ink, .18)!],
        ),
        border: ring ? Border.all(color: Colors.white.withValues(alpha: .9), width: 3) : null,
        boxShadow: ring ? const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))] : null,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: context.olText.bodyStrong.copyWith(color: ink, fontSize: size * .34, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ── Kartu hero bergradien ─────────────────────────────────────────────────────────────────────────

/// Kartu gradien merek dengan dua lingkaran cahaya yang bergerak pelan (ambient), untuk ringkasan di atas halaman.
class KHero extends StatefulWidget {
  const KHero({super.key, required this.child, this.padding = const EdgeInsets.all(OlSpace.xl)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<KHero> createState() => _KHeroState();
}

class _KHeroState extends State<KHero> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 9));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cahaya bergerak hanya di iOS: di Android repaint terus-menerus (apalagi di bawah header kaca) memberatkan.
    if (OlMotion.reduced(context) || !OlFrosted.enabled) {
      _c.stop();
      _c.value = .15;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return ClipRRect(
      borderRadius: BorderRadius.circular(OlRadius.card + 4),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: OlHeroBackdrop.gradient(c)),
        child: Stack(
          children: [
            // RepaintBoundary: repaint cahaya tidak ikut menggambar ulang isi kartu.
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(painter: _GlowPainter(_c.value, c.brand)),
                ),
              ),
            ),
            Padding(padding: widget.padding, child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.t, this.brand);
  final double t;
  final Color brand;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    void glow(Offset center, double r, Color color) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    glow(
      Offset(size.width * (.88 + .05 * math.cos(a)), size.height * (.1 + .08 * math.sin(a))),
      size.width * .45,
      brand.withValues(alpha: .55),
    );
    glow(
      Offset(size.width * (.05 + .05 * math.sin(a)), size.height * (1 + .06 * math.cos(a))),
      size.width * .35,
      Colors.white.withValues(alpha: .10),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}

/// Statistik: angka naik bertahap + label. [light] = di atas [KHero].
class KStat extends StatelessWidget {
  const KStat({super.key, required this.value, required this.label, this.icon, this.light = false, this.suffix = ''});
  final int? value;
  final String label;
  final OlIconData? icon;
  final bool light;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final fg = light ? Colors.white : c.fg;
    final sub = light ? Colors.white.withValues(alpha: .72) : c.muted;
    final style = t.title.copyWith(color: fg, fontSize: 24, height: 1.1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[OlIcon(icon!, size: 18, color: sub), const SizedBox(height: 6)],
        // Angka tidak pernah terlipat: mengecil bila kolom sempit; satuan lebih kecil dari angka.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: value == null
              ? Text('–', style: style)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    OlCountUp(value!, style: style),
                    if (suffix.isNotEmpty)
                      Text(
                        suffix,
                        style: style.copyWith(fontSize: 14, color: sub, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.caption.copyWith(color: sub, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Baris statistik dengan pemisah tipis.
class KStatRow extends StatelessWidget {
  const KStatRow({super.key, required this.children, this.light = false});
  final List<Widget> children;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final line = light ? Colors.white.withValues(alpha: .18) : context.ol.line;
    return IntrinsicHeight(
      child: Row(
        children: [
          for (final (i, w) in children.indexed) ...[
            if (i > 0)
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: OlSpace.md),
                color: line,
              ),
            Expanded(child: w),
          ],
        ],
      ),
    );
  }
}

/// Tombol kaca di atas [KHero].
class KGlassButton extends StatelessWidget {
  const KGlassButton({super.key, required this.icon, required this.label, required this.onTap, this.busy = false});
  final OlIconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => OlPressable(
    onTap: busy ? null : onTap,
    scale: .95,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(OlRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : OlIcon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.olText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

// ── Pil kecil ─────────────────────────────────────────────────────────────────────────────────────

enum KPillTone { brand, ok, warn, muted, gold, crit, glass }

class KPill extends StatelessWidget {
  const KPill(this.text, {super.key, this.icon, this.tone = KPillTone.muted, this.mono = false});
  final String text;
  final OlIconData? icon;
  final KPillTone tone;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final (bg, fg) = switch (tone) {
      KPillTone.brand => (c.brandSoft, c.brand),
      KPillTone.ok => (c.okSoft, c.ok),
      KPillTone.warn => (c.warnSoft, c.warn),
      KPillTone.gold => (c.goldSoft, c.gold),
      KPillTone.crit => (c.critSoft, c.crit),
      KPillTone.muted => (c.surfaceAlt, c.muted),
      KPillTone.glass => (Colors.white.withValues(alpha: .16), Colors.white),
    };
    final base = mono ? context.olText.mono.copyWith(fontSize: 12) : context.olText.caption;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(OlRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[OlIcon(icon!, size: 13, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titik status yang berdenyut pelan (mis. "menunggu").
class KPulseDot extends StatefulWidget {
  const KPulseDot({super.key, required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  State<KPulseDot> createState() => _KPulseDotState();
}

class _KPulseDotState extends State<KPulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OlMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: widget.size * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size * (1 + 1.4 * _c.value),
              height: widget.size * (1 + 1.4 * _c.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: .35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Form ──────────────────────────────────────────────────────────────────────────────────────────

/// Kotak ikon berwarna lembut.
class KIconBadge extends StatelessWidget {
  const KIconBadge(this.icon, {super.key, this.tone, this.size = 38});
  final OlIconData icon;
  final (Color, Color)? tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone ?? (context.ol.brandSoft, context.ol.brand);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .32)),
      alignment: Alignment.center,
      child: OlIcon(icon, size: size * .52, color: fg, weight: OlIconWeight.duotone),
    );
  }
}

/// Kelompok isian dalam kartu: ikon + judul + penanda kelengkapan (n/m → centang hijau).
class KFormSection extends StatelessWidget {
  const KFormSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.done,
    this.total,
  });

  final OlIconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Isian wajib yang sudah terisi / jumlah isian wajib di seksi ini (null = tanpa penanda).
  final int? done;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final complete = done != null && total != null && total! > 0 && done! >= total!;
    return OlCard(
      padding: const EdgeInsets.fromLTRB(OlSpace.lg, OlSpace.lg, OlSpace.lg, OlSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KIconBadge(icon),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.heading),
                    if (subtitle != null) Text(subtitle!, style: t.caption),
                  ],
                ),
              ),
              if (done != null && total != null && total! > 0)
                AnimatedSwitcher(
                  duration: OlMotion.of(context, const Duration(milliseconds: 260)),
                  switchInCurve: OlMotion.spring,
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: complete
                      ? Container(
                          key: const ValueKey('ok'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: c.ok, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const OlIcon(OlIcons.check, size: 16, color: Colors.white),
                        )
                      : KPill('$done/$total', key: ValueKey(done), tone: KPillTone.muted),
                ),
            ],
          ),
          const SizedBox(height: OlSpace.lg),
          for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(height: OlSpace.lg), w],
        ],
      ),
    );
  }
}

/// Kelengkapan form: batang progres beranimasi, berubah hijau saat lengkap.
class KFormProgress extends StatelessWidget {
  const KFormProgress({super.key, required this.done, required this.total, required this.label, this.doneLabel});
  final int done;
  final int total;
  final String label;
  final String? doneLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final v = total == 0 ? 1.0 : (done / total).clamp(0.0, 1.0);
    final complete = v >= 1;
    final color = complete ? c.ok : c.brand;
    return OlCard(
      padding: const EdgeInsets.fromLTRB(OlSpace.lg, 14, OlSpace.lg, OlSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: OlMotion.of(context, OlMotion.normal),
                  layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
                  child: Text(
                    complete ? (doneLabel ?? 'Siap disimpan') : label,
                    key: ValueKey(complete),
                    style: t.bodyStrong.copyWith(color: complete ? c.ok : c.fg),
                  ),
                ),
              ),
              Text(
                '$done/$total',
                style: t.mono.copyWith(fontSize: 13, color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(end: v),
            duration: OlMotion.of(context, const Duration(milliseconds: 420)),
            curve: OlMotion.emphasized,
            builder: (context, x, _) => ClipRRect(
              borderRadius: BorderRadius.circular(OlRadius.pill),
              child: Stack(
                children: [
                  Container(height: 8, color: c.surfaceAlt),
                  FractionallySizedBox(
                    widthFactor: x,
                    child: AnimatedContainer(
                      duration: OlMotion.of(context, OlMotion.slow),
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, .25)!, color]),
                        borderRadius: BorderRadius.circular(OlRadius.pill),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label isian (seragam dengan [OlTextField]).
class KFieldLabel extends StatelessWidget {
  const KFieldLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: context.ol.crit),
            ),
        ],
      ),
      style: context.olText.fieldLabel,
    ),
  );
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.text);
  final String? text;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: OlMotion.of(context, OlMotion.normal),
    curve: OlMotion.curve,
    alignment: Alignment.topLeft,
    child: text == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(text!, style: context.olText.caption.copyWith(color: context.ol.crit)),
          ),
  );
}

/// Isian yang membuka pemilih (tanggal, dst.) — bentuknya sama dengan [OlTextField].
class KPickerField extends StatelessWidget {
  const KPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Pilih',
    this.icon = OlIcons.calendar,
    this.required = false,
    this.error,
    this.trailing,
  });

  final String label;
  final String? value;
  final String placeholder;
  final OlIconData icon;
  final VoidCallback onTap;
  final bool required;
  final String? error;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KFieldLabel(label, required: required),
        Semantics(
          button: true,
          label: '$label: ${value ?? placeholder}',
          excludeSemantics: true,
          child: OlPressable(
            onTap: onTap,
            scale: .98,
            child: AnimatedContainer(
              duration: OlMotion.of(context, OlMotion.fast),
              height: OlSize.input,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(OlRadius.input),
                border: Border.all(color: hasError ? c.crit : c.line, width: 1.5),
                boxShadow: hasError ? [BoxShadow(color: c.critSoft, spreadRadius: 4)] : null,
              ),
              child: Row(
                children: [
                  OlIcon(icon, size: 20, color: value == null ? c.faint : c.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      style: t.body.copyWith(fontSize: 15, color: value == null ? c.faint : c.fg),
                    ),
                  ),
                  if (trailing != null) KPill(trailing!, tone: KPillTone.brand),
                  const SizedBox(width: 6),
                  OlIcon(OlIcons.chevronDown, size: 18, color: c.muted),
                ],
              ),
            ),
          ),
        ),
        _FieldError(error),
      ],
    );
  }
}

/// Pilihan berbentuk pil berdampingan (mis. jenis kelamin). Pil terpilih terisi warna merek dengan transisi halus.
class KChoice<T> extends StatelessWidget {
  const KChoice({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.error,
  });

  final String label;
  final List<(T, String, OlIconData?)> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool required;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final d = OlMotion.of(context, const Duration(milliseconds: 220));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KFieldLabel(label, required: required),
        Row(
          children: [
            for (final (i, o) in options.indexed) ...[
              if (i > 0) const SizedBox(width: OlSpace.sm),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: o.$1 == value,
                  label: o.$2,
                  excludeSemantics: true,
                  child: OlPressable(
                    onTap: () {
                      if (o.$1 != value) HapticFeedback.selectionClick();
                      onChanged(o.$1);
                    },
                    scale: .96,
                    child: AnimatedContainer(
                      duration: d,
                      curve: OlMotion.curve,
                      height: OlSize.input,
                      decoration: BoxDecoration(
                        color: o.$1 == value ? c.brand : c.surface,
                        borderRadius: BorderRadius.circular(OlRadius.input),
                        border: Border.all(
                          color: o.$1 == value ? c.brand : (error != null ? c.crit : c.line),
                          width: 1.5,
                        ),
                        boxShadow: o.$1 == value ? OlShadow.brandButton : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: d,
                            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                            child: o.$1 == value
                                ? const Padding(
                                    key: ValueKey('on'),
                                    padding: EdgeInsets.only(right: 6),
                                    child: OlIcon(OlIcons.checkCircle, size: 18, color: Colors.white),
                                  )
                                : (o.$3 == null
                                      ? const SizedBox.shrink(key: ValueKey('off'))
                                      : Padding(
                                          key: const ValueKey('ic'),
                                          padding: const EdgeInsets.only(right: 6),
                                          child: OlIcon(o.$3!, size: 18, color: c.muted),
                                        )),
                          ),
                          AnimatedDefaultTextStyle(
                            duration: d,
                            style: t.bodyStrong.copyWith(fontSize: 14.5, color: o.$1 == value ? Colors.white : c.fg),
                            child: Text(o.$2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        _FieldError(error),
      ],
    );
  }
}

// ── Isi data ──────────────────────────────────────────────────────────────────────────────────────

/// Satu data berikon (detail pasien): ikon kecil, label, nilai.
class KInfoTile extends StatelessWidget {
  const KInfoTile({super.key, required this.icon, required this.label, required this.value});
  final OlIconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      padding: const EdgeInsets.all(OlSpace.md),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OlIcon(icon, size: 18, color: c.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: t.bodyStrong.copyWith(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kisi 2 kolom; item [KGridItem.wide] memakai satu baris penuh.
class KGrid extends StatelessWidget {
  const KGrid({super.key, required this.items, this.gap = OlSpace.sm});
  final List<KGridItem> items;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final pending = <Widget>[];
    void flush() {
      if (pending.isEmpty) return;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: pending[0]),
              SizedBox(width: gap),
              Expanded(child: pending.length > 1 ? pending[1] : const SizedBox()),
            ],
          ),
        ),
      );
      pending.clear();
    }

    for (final it in items) {
      if (it.wide) {
        flush();
        rows.add(it.child);
      } else {
        pending.add(it.child);
        if (pending.length == 2) flush();
      }
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, r) in rows.indexed) ...[if (i > 0) SizedBox(height: gap), r],
      ],
    );
  }
}

class KGridItem {
  const KGridItem(this.child, {this.wide = false});
  final Widget child;
  final bool wide;
}

/// Blok teks berlabel (isi pemeriksaan / formulir).
class KTextBlock extends StatelessWidget {
  const KTextBlock({super.key, required this.icon, required this.label, required this.value});
  final OlIconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.trim().isEmpty || v.trim() == '-') return const SizedBox.shrink();
    final c = context.ol;
    final t = context.olText;
    return Padding(
      padding: const EdgeInsets.only(top: OlSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: OlIcon(icon, size: 16, color: c.faint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(v, style: t.body.copyWith(fontSize: 14.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kutipan keluhan: latar lembut + garis aksen kiri.
class KQuote extends StatelessWidget {
  const KQuote(this.text, {super.key, this.maxLines});
  final String text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: c.brand, width: 3)),
      ),
      child: Text(
        '“$text”',
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: context.olText.body.copyWith(fontSize: 14.5, height: 1.4, fontStyle: FontStyle.italic),
      ),
    );
  }
}

/// Baris ikon + teks kecil (meta di kartu).
class KMeta extends StatelessWidget {
  const KMeta(this.icon, this.text, {super.key, this.color, this.maxLines = 1});
  final OlIconData icon;
  final String text;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: OlIcon(icon, size: 14, color: color ?? c.faint),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: context.olText.caption.copyWith(color: color ?? c.muted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────────────────────────

/// Satu langkah timeline: titik (yang pertama berdenyut) + garis yang tumbuh ke bawah.
class KTimelineTile extends StatelessWidget {
  const KTimelineTile({super.key, required this.child, this.first = false, this.last = false, this.color});
  final Widget child;
  final bool first;
  final bool last;
  final Color? color;

  static const _rail = 26.0;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final dot = color ?? c.brand;
    // Stack + Positioned (bukan IntrinsicHeight): tinggi mengikuti isi kartu, garis direntang di sampingnya.
    return Stack(
      children: [
        if (!last)
          Positioned(
            left: _rail / 2 - 1,
            top: 38,
            bottom: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: OlMotion.reduced(context) ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: OlMotion.curve,
              builder: (context, v, _) => Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: v,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [dot.withValues(alpha: .5), c.line],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          top: 14,
          width: _rail,
          child: Center(
            child: first
                ? KPulseDot(color: dot, size: 10)
                : Padding(
                    padding: const EdgeInsets.all(7),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.surface,
                        border: Border.all(color: dot, width: 2.5),
                      ),
                    ),
                  ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: _rail + 8, bottom: last ? 0 : OlSpace.gap),
          child: child,
        ),
      ],
    );
  }
}

/// Lencana tanggal: angka hari besar + bulan.
class KDateBadge extends StatelessWidget {
  const KDateBadge({super.key, required this.date, this.highlight = false});
  final DateTime? date;
  final bool highlight;

  static const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final d = date;
    final bg = highlight ? c.brand : c.brandSoft;
    final fg = highlight ? Colors.white : c.brand;
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: highlight ? OlShadow.brandButton : null,
      ),
      child: Column(
        children: [
          Text(d == null ? '–' : '${d.day}', style: t.title.copyWith(color: fg, fontSize: 19, height: 1.05)),
          Text(
            d == null ? '' : '${_bulan[d.month - 1]} ${d.year % 100}'.toUpperCase(),
            style: t.caption.copyWith(color: fg, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4),
          ),
        ],
      ),
    );
  }
}

// ── Menu ──────────────────────────────────────────────────────────────────────────────────────────

class KMenuTile extends StatelessWidget {
  const KMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.tone,
    this.danger = false,
  });

  final OlIconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final (Color, Color)? tone;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlCard(
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          KIconBadge(icon, tone: danger ? (c.critSoft, c.crit) : tone, size: 44),
          const SizedBox(width: OlSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong.copyWith(color: danger ? c.crit : c.fg)),
                if (subtitle != null) Text(subtitle!, style: t.caption),
              ],
            ),
          ),
          if (!danger)
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: OlIcon(OlIcons.chevronRight, size: 16, color: c.muted),
            ),
        ],
      ),
    );
  }
}

/// Umur (tahun) dari tanggal lahir.
int? umur(DateTime? ttl, [DateTime? now]) {
  if (ttl == null) return null;
  final n = now ?? DateTime.now();
  var y = n.year - ttl.year;
  if (n.month < ttl.month || (n.month == ttl.month && n.day < ttl.day)) y--;
  return y < 0 ? null : y;
}

/// "Hari ini", "Kemarin", "3 hari lalu", lalu tanggal.
String relatif(DateTime? d, [DateTime? now]) {
  if (d == null) return '-';
  final n = now ?? DateTime.now();
  final a = DateTime(n.year, n.month, n.day);
  final b = DateTime(d.year, d.month, d.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  if (diff > 1 && diff < 7) return '$diff hari lalu';
  if (diff >= 7 && diff < 30) return '${diff ~/ 7} minggu lalu';
  return '${b.day} ${KDateBadge._bulan[b.month - 1]} ${b.year}';
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../feedback/app_feedback.dart';
import '../ol_button.dart';
import 'body_map_data.dart';
import 'body_map_selection.dart';

export 'body_map_selection.dart';

/// Warna peta tubuh (D.2b).
abstract final class BodyColors {
  static const base = Color(0xFFE3EBF2);
  static const outline = Color(0xFFB7C7D4);
  static const hair = Color(0xFFC9D6E1);
  static const silhouette = Color(0xFFF5F8FB);
  static const treated = Color(0xFF0277B5);
  static const calming = Color(0xFFF2B263);
  static const calmSoft = Color(0xFFFDF1DF);
  static const calmInk = Color(0xFF8A4B06);

  static Color of(BodyMode? m) => switch (m) {
        BodyMode.treated => treated,
        BodyMode.calming => calming,
        null => base,
      };
}

/// BodyMap (§4, D.2b): siluet depan & belakang, ketuk otot → tandai dengan [mode] aktif.
/// Ketuk lagi dengan mode sama → hapus. Area sama di dua tampak ikut tertandai.
class BodyMap extends StatefulWidget {
  const BodyMap({super.key, required this.selection, required this.mode, required this.onChanged});

  final BodyMapSelection selection;
  final BodyMode mode;
  final ValueChanged<BodyMapSelection> onChanged;

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> with TickerProviderStateMixin {
  late final Future<BodyMapData> _data = BodyMapData.load();

  late final _color = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  String? _colorKey;
  Color _colorFrom = BodyColors.base;
  String? _pulseKey;
  List<String> _flashKeys = const [];
  String? _tip;
  Timer? _tipTimer;

  bool get _reduced => OlMotion.reduced(context);

  @override
  void dispose() {
    _tipTimer?.cancel();
    _color.dispose();
    _pulse.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _tapKey(String key) {
    final before = widget.selection.modeOf(key);
    final next = widget.selection.toggle(key, widget.mode);
    HapticFeedback.selectionClick();
    _colorKey = key;
    _colorFrom = BodyColors.of(before);
    if (!_reduced) {
      _color.forward(from: 0);
      if (next.modeOf(key) != null) {
        _pulseKey = key;
        _pulse.forward(from: 0);
      }
    } else {
      _color.value = 1;
    }
    _showTip(bodyAreaLabel(key));
    widget.onChanged(next);
  }

  void _showTip(String text) {
    _tipTimer?.cancel();
    setState(() => _tip = text);
    _tipTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _tip = null);
    });
  }

  void _flashKeysNow(List<String> keys) {
    if (_reduced) return;
    _flashKeys = keys;
    _flash.forward(from: 0);
  }

  void _onTapFigure(BodyView view, Offset local, Size size) {
    final s = size.width / view.viewBox.width;
    final p = Offset(local.dx / s + view.viewBox.left, local.dy / s + view.viewBox.top);
    final m = view.hit(p);
    if (m != null) _tapKey(m.key);
  }

  Future<void> _openList(BodyMapData data) async {
    final keys = <String>{
      for (final m in data.front.muscles) m.key,
      for (final m in data.back.muscles) m.key,
    }.toList()
      ..sort((a, b) => bodyAreaLabel(a).compareTo(bodyAreaLabel(b)));
    await context.feedback.formSheet<void>(
      title: widget.mode == BodyMode.treated ? 'Pilih area ditangani' : 'Pilih area penenang',
      message: 'Untuk otot kecil atau pembaca layar. Ketuk lagi untuk menghapus.',
      builder: (context, close) => _AreaList(
        keys: keys,
        selection: widget.selection,
        mode: widget.mode,
        onToggle: (k) {
          final next = widget.selection.toggle(k, widget.mode);
          widget.onChanged(next);
          return next;
        },
        onDone: () => close(null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    final sel = widget.selection;
    final summary = sel.areas.isEmpty
        ? 'Belum ada area dipilih'
        : sel.chips().map((ch) => ch.text).join(', ');

    return FutureBuilder<BodyMapData>(
      future: _data,
      builder: (context, snap) {
        final data = snap.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Peta tubuh. $summary.',
              hint: 'Gunakan tombol Daftar area untuk memilih dengan pembaca layar.',
              child: Container(
                decoration: BoxDecoration(color: BodyColors.silhouette, borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
                child: data == null
                    ? const AspectRatio(aspectRatio: 1.05, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    : Stack(
                        children: [
                          Row(
                            children: [
                              for (final (view, label) in [(data.front, 'Depan'), (data.back, 'Belakang')])
                                Expanded(
                                  child: Column(
                                    children: [
                                      AspectRatio(
                                        aspectRatio: view.viewBox.width / view.viewBox.height,
                                        child: LayoutBuilder(
                                          builder: (context, box) => GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapUp: (d) => _onTapFigure(view, d.localPosition, box.biggest),
                                            child: ExcludeSemantics(
                                              child: AnimatedBuilder(
                                                animation: Listenable.merge([_color, _pulse, _flash]),
                                                builder: (context, _) => CustomPaint(
                                                  size: box.biggest,
                                                  painter: _BodyPainter(
                                                    view: view,
                                                    selection: sel,
                                                    colorKey: _colorKey,
                                                    colorFrom: _colorFrom,
                                                    colorT: _color.isAnimating ? Curves.easeOut.transform(_color.value) : 1,
                                                    pulseKey: _pulse.isAnimating ? _pulseKey : null,
                                                    pulseT: _pulse.value,
                                                    flashKeys: _flash.isAnimating ? _flashKeys : const [],
                                                    flashT: _flash.value,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(label, style: t.body.copyWith(color: c.muted)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          // Label area: turun 6dp & muncul, hilang setelah 1,2 dtk.
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Center(
                                child: AnimatedSlide(
                                  duration: _reduced ? Duration.zero : const Duration(milliseconds: 150),
                                  offset: _tip == null ? const Offset(0, -0.25) : Offset.zero,
                                  child: AnimatedOpacity(
                                    duration: _reduced ? Duration.zero : const Duration(milliseconds: 150),
                                    opacity: _tip == null ? 0 : 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: c.toastBg,
                                        borderRadius: BorderRadius.circular(OlRadius.pill),
                                      ),
                                      child: Text(
                                        _tip ?? '',
                                        style: t.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const _LegendDot(color: BodyColors.treated, label: 'Ditangani'),
                const SizedBox(width: 14),
                const _LegendDot(color: BodyColors.calming, label: 'Penenang'),
                const Spacer(),
                if (data != null)
                  TextButton(
                    onPressed: () => _openList(data),
                    style: TextButton.styleFrom(
                      foregroundColor: c.brand,
                      textStyle: t.caption.copyWith(fontWeight: FontWeight.w700),
                      minimumSize: const Size(48, 40),
                    ),
                    child: const Text('Daftar area'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _AnimatedChips(
              chips: sel.chips(),
              onTapChip: (ch) => _flashKeysNow(ch.keys),
              onRemove: (ch) {
                HapticFeedback.selectionClick();
                widget.onChanged(widget.selection.removeAll(ch.keys));
              },
            ),
          ],
        );
      },
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.view,
    required this.selection,
    required this.colorKey,
    required this.colorFrom,
    required this.colorT,
    required this.pulseKey,
    required this.pulseT,
    required this.flashKeys,
    required this.flashT,
  });

  final BodyView view;
  final BodyMapSelection selection;
  final String? colorKey;
  final Color colorFrom;
  final double colorT;
  final String? pulseKey;
  final double pulseT;
  final List<String> flashKeys;
  final double flashT;

  /// Skala 1 → 1,07 (di 40%) → 1, kurva Cubic(.2,.8,.2,1).
  double get _pulseScale {
    final e = const Cubic(.2, .8, .2, 1).transform(pulseT);
    return e < .4 ? 1 + .07 * (e / .4) : 1 + .07 * (1 - (e - .4) / .6);
  }

  /// Opasitas 1 → 0,35 (di 30%) → 1.
  double get _flashOpacity => flashT < .3 ? 1 - .65 * (flashT / .3) : .35 + .65 * ((flashT - .3) / .7);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / view.viewBox.width;
    canvas.save();
    canvas.scale(s);
    canvas.translate(-view.viewBox.left, -view.viewBox.top);

    canvas.drawPath(view.outline, Paint()..color = BodyColors.silhouette);
    canvas.drawPath(
      view.outline,
      Paint()
        ..color = BodyColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    void drawMuscle(BodyMuscle m) {
      var color = BodyColors.of(selection.modeOf(m.key));
      if (m.key == colorKey && colorT < 1) color = Color.lerp(colorFrom, color, colorT)!;
      if (flashKeys.contains(m.key)) color = color.withValues(alpha: _flashOpacity);
      canvas.drawPath(m.path, Paint()..color = color);
      canvas.drawPath(m.path, stroke);
    }

    BodyMuscle? pulsing;
    for (final m in view.muscles) {
      if (m.key == pulseKey) {
        pulsing ??= m;
        // Otot berdenyut digambar terakhir agar di atas tetangganya.
        continue;
      }
      drawMuscle(m);
    }
    for (final m in view.muscles.where((m) => m.key == pulseKey)) {
      final c = m.bounds.center;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(_pulseScale);
      canvas.translate(-c.dx, -c.dy);
      drawMuscle(m);
      canvas.restore();
    }
    if (view.hair != null) {
      canvas.drawPath(view.hair!, Paint()..color = BodyColors.hair);
      canvas.drawPath(view.hair!, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) => true;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: context.olText.caption.copyWith(fontSize: 13)),
        ],
      );
}

/// Chip area dengan animasi masuk (skala 0,85→1 + fade, 200ms) & keluar (150ms).
class _AnimatedChips extends StatefulWidget {
  const _AnimatedChips({required this.chips, required this.onTapChip, required this.onRemove});

  final List<BodyAreaChip> chips;
  final ValueChanged<BodyAreaChip> onTapChip;
  final ValueChanged<BodyAreaChip> onRemove;

  @override
  State<_AnimatedChips> createState() => _AnimatedChipsState();
}

class _AnimatedChipsState extends State<_AnimatedChips> {
  final _leaving = <String, BodyAreaChip>{};
  late List<BodyAreaChip> _shown = widget.chips;

  @override
  void didUpdateWidget(_AnimatedChips old) {
    super.didUpdateWidget(old);
    final now = {for (final c in widget.chips) c.id};
    for (final c in old.chips) {
      if (!now.contains(c.id)) _leaving[c.id] = c;
    }
    _leaving.removeWhere((id, _) => now.contains(id));
    _shown = widget.chips;
  }

  @override
  Widget build(BuildContext context) {
    final reduced = OlMotion.reduced(context);
    if (_shown.isEmpty && _leaving.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text('Belum ada area. Ketuk siluet untuk menandai.', style: context.olText.caption.copyWith(fontSize: 13)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final ch in _shown)
          _ChipMotion(
            key: ValueKey(ch.id),
            reduced: reduced,
            child: _AreaChip(chip: ch, onTap: () => widget.onTapChip(ch), onRemove: () => widget.onRemove(ch)),
          ),
        if (!reduced)
          for (final ch in _leaving.values)
            _ChipMotion(
              key: ValueKey('out-${ch.id}'),
              leaving: true,
              reduced: reduced,
              onDone: () {
                if (mounted) setState(() => _leaving.remove(ch.id));
              },
              child: IgnorePointer(child: _AreaChip(chip: ch, onTap: () {}, onRemove: () {})),
            ),
      ],
    );
  }
}

class _ChipMotion extends StatelessWidget {
  const _ChipMotion({super.key, required this.child, required this.reduced, this.leaving = false, this.onDone});

  final Widget child;
  final bool reduced;
  final bool leaving;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    if (reduced) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: leaving ? 1 : 0, end: leaving ? 0 : 1),
      duration: Duration(milliseconds: leaving ? 150 : 200),
      curve: leaving ? Curves.easeIn : OlMotion.curve,
      onEnd: onDone,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.scale(scale: .85 + .15 * v, child: child),
      ),
      child: child,
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({required this.chip, required this.onTap, required this.onRemove});

  final BodyAreaChip chip;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final treated = chip.mode == BodyMode.treated;
    final fg = treated ? Colors.white : BodyColors.calmInk;
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: treated ? context.ol.brandDeep : BodyColors.calmSoft,
        borderRadius: BorderRadius.circular(OlRadius.pill),
        border: treated ? null : Border.all(color: BodyColors.calming, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            button: true,
            label: '${chip.text}, ketuk untuk menyorot di peta',
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(OlRadius.pill)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 4, 9),
                child: Text(chip.text, style: t.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg)),
              ),
            ),
          ),
          Semantics(
            container: true,
            button: true,
            label: 'Hapus ${chip.text}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 36,
                height: 40,
                child: Center(child: Text('×', style: t.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: fg))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Daftar area (alternatif untuk pembaca layar & otot kecil < 44dp, D.2b).
class _AreaList extends StatefulWidget {
  const _AreaList({required this.keys, required this.selection, required this.mode, required this.onToggle, required this.onDone});

  final List<String> keys;
  final BodyMapSelection selection;
  final BodyMode mode;
  final BodyMapSelection Function(String key) onToggle;
  final VoidCallback onDone;

  @override
  State<_AreaList> createState() => _AreaListState();
}

class _AreaListState extends State<_AreaList> {
  late BodyMapSelection _sel = widget.selection;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.min(420, MediaQuery.sizeOf(context).height * .5)),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final k in widget.keys)
                CheckboxListTile(
                  value: _sel.modeOf(k) == widget.mode,
                  onChanged: (_) => setState(() => _sel = widget.onToggle(k)),
                  title: Text(bodyAreaLabel(k), style: t.body.copyWith(fontSize: 15)),
                  subtitle: _sel.modeOf(k) != null && _sel.modeOf(k) != widget.mode
                      ? Text(
                          _sel.modeOf(k) == BodyMode.treated ? 'Saat ini: ditangani' : 'Saat ini: penenang',
                          style: t.caption,
                        )
                      : null,
                  activeColor: widget.mode == BodyMode.treated ? BodyColors.treated : BodyColors.calming,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  side: BorderSide(color: c.faint, width: 1.5),
                ),
            ],
          ),
        ),
        const SizedBox(height: OlSpace.md),
        OlButton(label: 'Selesai', onPressed: widget.onDone),
      ],
    );
  }
}

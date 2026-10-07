import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

enum _Step { password, pin, notification, context }

/// UM-05 Login pertama: (1) ganti password sementara → (2) PIN 6 digit + biometrik →
/// (3) izin notifikasi → (4) pilih cabang & peran (UM-08, bila >1).
/// Tidak bisa dilewati kecuali izin notifikasi & biometrik.
class FirstLoginPage extends ConsumerStatefulWidget {
  const FirstLoginPage({super.key});

  @override
  ConsumerState<FirstLoginPage> createState() => _FirstLoginPageState();
}

class _FirstLoginPageState extends ConsumerState<FirstLoginPage> {
  late final List<_Step> _steps;
  int _index = 0;
  bool _busy = false;

  // Langkah 1
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();

  // Langkah 2
  String _pin = '';
  String? _firstPin;
  bool _pinMismatch = false;
  bool _bioAvailable = false;
  bool _bioOn = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(authProvider);
    _steps = [
      if (s.firstLoginStartStep <= 1) _Step.password,
      _Step.pin,
      _Step.notification,
      if (s.user!.needsContextChoice) _Step.context,
    ];
    ref.read(authProvider.notifier).biometricAvailable().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  _Step get _step => _steps[_index];

  void _next() => setState(() => _index++);

  // ── Langkah 1 ────────────────────────────────────────────────────────────

  bool get _pwLongEnough => _pw.text.length >= AuthRules.minPasswordLength;
  bool get _pwDiffers =>
      _pw.text.isNotEmpty &&
      !ref.read(authProvider.notifier).isSameAsTemporary(_pw.text);
  bool get _pwMatch => _pw2.text.isNotEmpty && _pw.text == _pw2.text;
  bool get _pwValid => _pwLongEnough && _pwDiffers && _pwMatch;

  Future<void> _submitPassword() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).changeTemporaryPassword(_pw.text);
      if (mounted) _next();
    } catch (_) {
      if (mounted) {
        context.feedback.error(
          const AppError(ErrorCode.serverError),
          retry: _submitPassword,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Langkah 2 ────────────────────────────────────────────────────────────

  void _pinDigit(String d) {
    if (_pin.length >= AuthRules.pinLength) return;
    setState(() {
      _pin += d;
      _pinMismatch = false;
    });
    if (_pin.length < AuthRules.pinLength) return;
    if (_firstPin == null) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
      });
    } else if (_firstPin != _pin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pinMismatch = true;
        _firstPin = null;
        _pin = '';
      });
    }
  }

  bool get _pinReady => _firstPin != null && _pin == _firstPin;

  Future<void> _submitPin() async {
    setState(() => _busy = true);
    final auth = ref.read(authProvider.notifier);
    await auth.setPin(_pin);
    if (_bioOn) {
      final ok = await auth.enableBiometric();
      if (!ok && mounted) {
        context.feedback.info(
          'Biometrik belum aktif. Bisa diatur nanti di Akun.',
        );
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _next();
  }

  // ── Langkah 3 & 4 ────────────────────────────────────────────────────────

  Future<void> _notifications({required bool allow}) async {
    setState(() => _busy = true);
    final auth = ref.read(authProvider.notifier);
    if (allow) await auth.requestNotificationPermission();
    if (!mounted) return;
    // Redirect berikutnya: UM-08 (langkah 4) bila akun punya >1 peran/cabang, atau beranda peran.
    await auth.completeFirstLogin();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;

    final (
      String title,
      String subtitle,
      List<Widget> body,
      List<Widget> foot,
    ) = switch (_step) {
      _Step.password => (
        'Buat password baru',
        'Password sementara dari admin harus diganti sebelum kamu mulai bekerja.',
        _passwordBody(),
        [
          OlButton(
            label: 'Lanjut',
            loading: _busy,
            onPressed: _pwValid ? _submitPassword : null,
          ),
        ],
      ),
      _Step.pin => (
        _firstPin == null ? 'Atur PIN 6 digit' : 'Ulangi PIN',
        'PIN dipakai untuk membuka aplikasi setelah tidak aktif 5 menit.',
        _pinBody(),
        [
          OlButton(
            label: 'Lanjut',
            loading: _busy,
            onPressed: _pinReady ? _submitPin : null,
          ),
        ],
      ),
      _Step.notification => (
        'Izinkan notifikasi',
        'Supaya kamu tahu saat ada sesi baru, pasien hadir, atau catatan gagal terkirim. Isi notifikasi tidak memuat data medis.',
        [
          const SizedBox(height: 12),
          const Center(
            child: OlIllustrationImage(OlIllustration.reminder, width: 220),
          ),
        ],
        [
          OlButton(
            label: 'Izinkan notifikasi',
            icon: OlIcons.bell,
            loading: _busy,
            onPressed: () => _notifications(allow: true),
          ),
          OlButton.text(
            label: 'Nanti saja',
            expand: true,
            onPressed: _busy ? null : () => _notifications(allow: false),
          ),
        ],
      ),
      // Langkah 4 ditampilkan oleh layar UM-08 (ChooseContextPage).
      _Step.context => ('', '', const <Widget>[], const <Widget>[]),
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    OlSpace.screen,
                    20,
                    OlSpace.screen,
                    24,
                  ),
                  children: [
                    _Stepper(count: _steps.length, current: _index),
                    const SizedBox(height: 14),
                    Text(
                      'Langkah ${_index + 1} dari ${_steps.length} · Login pertama',
                      style: t.caption.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      header: true,
                      child: Text(title, style: t.title.copyWith(fontSize: 26)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: t.body.copyWith(fontSize: 15, color: c.muted),
                    ),
                    const SizedBox(height: 24),
                    ...body,
                    if (_index < _steps.length - 1) ...[
                      const SizedBox(height: 28),
                      Text('BERIKUTNYA', style: t.overline),
                      const SizedBox(height: 10),
                      for (var i = _index + 1; i < _steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${i + 1} · ${_stepName(_steps[i])}',
                            style: t.body.copyWith(color: c.muted),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              OlFootBar(children: foot),
            ],
          ),
        ),
      ),
    );
  }

  static String _stepName(_Step s) => switch (s) {
    _Step.password => 'Buat password baru',
    _Step.pin => 'Atur PIN 6 digit & biometrik',
    _Step.notification => 'Izinkan notifikasi (bisa dilewati)',
    _Step.context => 'Pilih cabang & peran',
  };

  List<Widget> _passwordBody() {
    final c = context.ol;
    final t = context.olText;
    final strength = passwordStrength(_pw.text);
    return [
      OlTextField(
        label: 'Password baru',
        isRequired: true,
        controller: _pw,
        obscure: true,
        autofillHints: const [AutofillHints.newPassword],
        onChanged: (_) => setState(() {}),
      ),
      if (_pw.text.isNotEmpty) ...[
        const SizedBox(height: 10),
        _StrengthBar(strength: strength),
      ],
      const SizedBox(height: 20),
      OlTextField(
        label: 'Ulangi password baru',
        isRequired: true,
        controller: _pw2,
        obscure: true,
        error:
            _pw2.text.isNotEmpty &&
                !_pwMatch &&
                _pw2.text.length >= _pw.text.length
            ? 'Password belum cocok.'
            : null,
        onChanged: (_) => setState(() {}),
      ),
      if (_pwMatch) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            OlIcon(OlIcons.check, size: 16, color: c.ok),
            const SizedBox(width: 4),
            Text(
              'Password cocok',
              style: t.body.copyWith(color: c.ok, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      OlCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SYARAT', style: t.overline),
            const SizedBox(height: 4),
            _Requirement(
              met: _pwLongEnough,
              label: 'Minimal ${AuthRules.minPasswordLength} karakter',
            ),
            _Requirement(
              met: _pwDiffers,
              label: 'Berbeda dari password sementara',
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _pinBody() {
    final c = context.ol;
    final t = context.olText;
    return [
      Center(
        child: PinDots(filled: _pin.length, error: _pinMismatch),
      ),
      const SizedBox(height: 12),
      Center(
        child: Semantics(
          liveRegion: true,
          child: Text(
            _pinMismatch
                ? 'PIN tidak cocok. Ulangi dari awal.'
                : (_pinReady
                      ? 'PIN cocok'
                      : (_firstPin == null
                            ? 'Masukkan 6 angka'
                            : 'Masukkan PIN yang sama sekali lagi')),
            style: t.body.copyWith(
              fontSize: 13,
              color: _pinMismatch ? c.crit : (_pinReady ? c.ok : c.muted),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      PinPad(
        enabled: !_pinReady,
        onDigit: _pinDigit,
        onDelete: () {
          if (_pin.isNotEmpty) {
            setState(() => _pin = _pin.substring(0, _pin.length - 1));
          }
        },
      ),
      if (_bioAvailable) ...[
        const SizedBox(height: 16),
        OlCheckbox(
          label: 'Buka dengan sidik jari / wajah',
          value: _bioOn,
          onChanged: (v) => setState(() => _bioOn = v),
        ),
      ],
    ];
  }
}

enum PasswordStrength { weak, medium, strong }

/// Penilaian sederhana untuk indikator kekuatan (UM-05).
PasswordStrength passwordStrength(String p) {
  var score = 0;
  if (p.length >= AuthRules.minPasswordLength) score++;
  if (p.length >= 12) score++;
  if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) score++;
  if (RegExp(r'\d').hasMatch(p)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
  if (p.length < AuthRules.minPasswordLength || score <= 2) {
    return PasswordStrength.weak;
  }
  return score == 3 ? PasswordStrength.medium : PasswordStrength.strong;
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.strength});
  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final (double value, Color color, String label) = switch (strength) {
      PasswordStrength.weak => (0.33, c.crit, 'Lemah'),
      PasswordStrength.medium => (0.66, c.warn, 'Sedang'),
      PasswordStrength.strong => (1.0, c.ok, 'Kuat'),
    };
    return Semantics(
      label: 'Kekuatan password: $label',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                color: color,
                backgroundColor: c.surfaceAlt,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: context.olText.body.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.met, required this.label});
  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Semantics(
      label: '$label, ${met ? 'terpenuhi' : 'belum terpenuhi'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: OlMotion.of(context, OlMotion.fast),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: met ? c.ok : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: met
                    ? null
                    : Border.all(color: const Color(0xFFB3C3D0), width: 2),
              ),
              child: met
                  ? const OlIcon(OlIcons.check, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: context.olText.body.copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: OlMotion.of(context),
              height: 5,
              decoration: BoxDecoration(
                color: i <= current
                    ? context.ol.brand
                    : const Color(0xFFDDE6ED),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

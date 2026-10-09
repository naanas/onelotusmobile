import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/auth/auth_controller.dart';
import '../../pasien/pasien_routes.dart';
import '../../pasien/pasien_session.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-04 Masuk — satu pintu untuk staf & pasien (+ UM-04b terkunci setelah gagal 5×).
/// Isian dikenali otomatis: nomor HP → pasien (kode OTP WhatsApp, PS-02);
/// selain itu → username staf + password.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _busy = false;
  String? _usernameError;
  String? _passwordError;
  String? _formError;
  DateTime? _lockedUntil;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    ref.read(authProvider.notifier).loginLockedUntil().then((until) {
      if (until != null && mounted) _startLock(until);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Duration get _lockRemaining {
    final until = _lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(ref.read(clockProvider)());
    return left.isNegative ? Duration.zero : left;
  }

  void _startLock(DateTime until) {
    _ticker?.cancel();
    setState(() => _lockedUntil = until);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lockRemaining == Duration.zero) {
        _ticker?.cancel();
        setState(() {
          _lockedUntil = null;
          _formError = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  /// Hanya angka (boleh +, spasi, tanda hubung) → dianggap nomor HP.
  static final _phoneLike = RegExp(r'^\+?[\d\s-]+$');

  bool get _isPhone {
    final v = _username.text.trim();
    return v.isNotEmpty && _phoneLike.hasMatch(v);
  }

  bool get _isStaff => _username.text.trim().isNotEmpty && !_isPhone;

  /// 08xx / 628xx / +628xx → "0812 3456 7890".
  static String _normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('62')) d = '0${d.substring(2)}';
    return [
      for (var i = 0; i < d.length; i += 4)
        d.substring(i, (i + 4).clamp(0, d.length)),
    ].join(' ');
  }

  Future<void> _submit() async {
    final id = _username.text.trim();
    if (id.isEmpty) {
      setState(() => _usernameError = 'Isi nomor HP atau username.');
      return;
    }
    if (_isPhone) return _submitPhone(id);

    final username = id;
    final password = _password.text;
    setState(() {
      _usernameError = username.contains(' ')
          ? 'Username tidak boleh berisi spasi.'
          : null;
      _passwordError = password.isEmpty ? 'Password wajib diisi.' : null;
      _formError = null;
    });
    if (_usernameError != null || _passwordError != null) return;

    setState(() => _busy = true);
    final outcome = await ref
        .read(authProvider.notifier)
        .login(username, password, remember: _remember);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case LoginOk():
        TextInput.finishAutofillContext();
      case LoginInvalid(:final remainingAttempts):
        _password.clear();
        setState(
          () => _formError = remainingAttempts <= 2
              ? 'Username atau password tidak cocok. Sisa $remainingAttempts percobaan.'
              : 'Username atau password tidak cocok.',
        );
      case LoginLocked(:final until):
        _password.clear();
        setState(() => _formError = 'Username atau password tidak cocok.');
        _startLock(until);
      case LoginDisabled():
        setState(() => _formError = 'Akun ini dinonaktifkan. Hubungi admin.');
      case LoginError(:final error):
        context.feedback.error(error, retry: _submit);
    }
  }

  /// Pasien: kirim kode OTP lewat WhatsApp → layar kode (PS-02).
  Future<void> _submitPhone(String raw) async {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(
        () => _usernameError = 'Nomor HP belum lengkap — minimal 10 digit.',
      );
      return;
    }
    setState(() {
      _usernameError = null;
      _busy = true;
    });
    // Slicing UI: anggap kode terkirim; nanti POST /pasien/otp.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _busy = false);
    ref.read(pasienSessionProvider.notifier).requestOtp(_normalizePhone(raw));
    context.go(PRoutes.masuk);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final locked = _lockedUntil != null;

    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: OlLogoMark(size: 44, color: Color(0xFF0277B5)),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  'Masuk ke One Lotus',
                  style: t.title.copyWith(fontSize: 28),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pasien: pakai nomor HP. Staf klinik: pakai username dari admin.',
                style: t.body.copyWith(fontSize: 15, color: c.muted),
              ),
              const SizedBox(height: 28),
              if (locked) ...[
                OlBanner(
                  tone: OlBannerTone.crit,
                  icon: OlIcons.lock,
                  message:
                      'Terlalu banyak percobaan gagal.\nCoba lagi dalam ${Fmt.countdown(_lockRemaining)}.',
                ),
                const SizedBox(height: 20),
              ],
              OlTextField(
                label: 'Nomor HP atau username',
                isRequired: true,
                controller: _username,
                error: _usernameError,
                hint: 'mis. 0812 3456 7890 atau dimas.terapis',
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.telephoneNumber,
                ],
                onChanged: (_) => setState(() => _usernameError = null),
                onSubmitted: (_) {
                  if (_isPhone && !_busy) _submit();
                },
              ),
              // Kolom staf muncul hanya bila yang diketik username.
              AnimatedSize(
                duration: OlMotion.of(context),
                curve: OlMotion.curve,
                alignment: Alignment.topCenter,
                child: _isStaff
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          OlTextField(
                            label: 'Password',
                            isRequired: true,
                            controller: _password,
                            obscure: true,
                            hint: 'Password',
                            error: _passwordError ?? _formError,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) =>
                                locked || _busy ? null : _submit(),
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          OlCheckbox(
                            label: 'Ingat perangkat ini',
                            value: _remember,
                            onChanged: (v) => setState(() => _remember = v),
                          ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 20),
              OlButton(
                label: _isPhone ? 'Kirim kode lewat WhatsApp' : 'Masuk',
                loading: _busy,
                onPressed: locked && !_isPhone ? null : _submit,
              ),
              if (_isPhone) ...[
                const SizedBox(height: 12),
                Text(
                  'Kode masuk dikirim lewat WhatsApp ke nomor ini.',
                  textAlign: TextAlign.center,
                  style: t.caption.copyWith(fontSize: 13),
                ),
              ],
              if (!_isPhone) ...[
                const SizedBox(height: 12),
                Center(
                  child: OlButton.text(
                    label: 'Lupa password?',
                    onPressed: () => context.push(Routes.forgotPassword),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Pasien baru yang sedang di klinik: isi formulir intake (WB-01) lewat QR front desk.
              Center(
                child: OlButton.text(
                  label: 'Pasien baru di klinik? Isi formulir',
                  onPressed: () => context.push(Routes.intakeScan),
                ),
              ),
              const SizedBox(height: 12),
              if (_isStaff)
                Text(
                  'Gagal ${AuthRules.maxLoginAttempts} kali akan mengunci login selama ${AuthRules.loginLockout.inMinutes} menit.',
                  textAlign: TextAlign.center,
                  style: t.caption.copyWith(fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

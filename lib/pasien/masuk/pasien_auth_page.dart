import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_session.dart';

enum PasienAuthMode { daftar, lupa }

/// PS-02 Daftar akun pasien / Lupa password, tiga langkah:
/// 1. nomor HP → kode OTP dikirim lewat WhatsApp;
/// 2. kode 6 digit langsung divalidasi begitu terisi (kode hangus setelah benar);
/// 3. nomor terverifikasi → buat password (+ ulangi).
/// Setelah daftar, tahap berikut (hubungkan data lama / isi data diri / persetujuan) diatur router.
class PasienAuthPage extends ConsumerStatefulWidget {
  const PasienAuthPage({super.key, required this.mode, this.phone});
  final PasienAuthMode mode;
  final String? phone;

  @override
  ConsumerState<PasienAuthPage> createState() => _PasienAuthPageState();
}

class _PasienAuthPageState extends ConsumerState<PasienAuthPage> {
  late final _phone = TextEditingController(text: widget.phone ?? '');
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _checking = false;

  /// Token verifikasi dari server = nomor sudah terbukti → langkah password.
  String? _verified;
  String? _phoneError, _codeError, _passwordError, _password2Error;
  int _resendIn = 0;
  Timer? _timer;

  bool get _daftar => widget.mode == PasienAuthMode.daftar;
  String get _purpose => _daftar ? 'register' : 'reset_password';
  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  void _countdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 999));
      if (_resendIn == 0) t.cancel();
    });
  }

  String? _apiMessage(AppError e) =>
      e.fieldErrors.values.expand((v) => v).firstOrNull ?? e.apiMessage;

  /// Langkah 1: kirim kode OTP lewat WhatsApp.
  Future<void> _sendCode() async {
    if (_digits.length < 10) {
      setState(
        () => _phoneError = 'Nomor HP belum lengkap — minimal 10 digit.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _phoneError = null;
      _codeError = null;
      _code.clear();
    });
    try {
      final wait = await ref
          .read(pasienSessionProvider.notifier)
          .requestOtp(_digits, _purpose);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _countdown(wait);
      _codeFocus.requestFocus();
    } on AppError catch (e) {
      if (!mounted) return;
      if (e.fieldError('phone') != null || e.apiCode == 'conflict') {
        setState(() => _phoneError = _apiMessage(e));
      } else if (e.apiMessage != null) {
        context.feedback.info(e.apiMessage!);
      } else {
        context.feedback.error(e, retry: _sendCode);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Langkah 2: validasi kode begitu 6 digit terisi.
  Future<void> _checkCode() async {
    if (_code.text.length != 6 || _checking) return;
    setState(() {
      _checking = true;
      _codeError = null;
    });
    try {
      final token = await ref
          .read(pasienSessionProvider.notifier)
          .verifyCode(_digits, _purpose, _code.text);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _timer?.cancel();
      setState(() => _verified = token);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _codeError = _apiMessage(e) ?? 'Kode salah atau kedaluwarsa.';
        _code.clear();
      });
    } finally {
      if (mounted) {
        setState(() => _checking = false);
        // Kode salah → kotak aktif lagi, fokus kembali untuk mengetik ulang.
        if (_verified == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _codeFocus.requestFocus(),
          );
        }
      }
    }
  }

  /// Langkah 3: buat password.
  Future<void> _submit() async {
    final pw = _password.text;
    setState(() {
      _passwordError = pw.length >= 8 ? null : 'Password minimal 8 karakter.';
      _password2Error = _password2.text == pw ? null : 'Password tidak sama.';
    });
    if (_passwordError != null || _password2Error != null) return;
    setState(() => _busy = true);
    final session = ref.read(pasienSessionProvider.notifier);
    try {
      if (_daftar) {
        // Berhasil → router membawa ke Hubungkan data / Persetujuan / Beranda.
        await session.register(_digits, _verified!, pw);
      } else {
        await session.resetPassword(_digits, _verified!, pw);
        if (!mounted) return;
        context.feedback.success(
          'Password diganti. Silakan masuk dengan password baru.',
        );
        context.go(Routes.login);
      }
    } on AppError catch (e) {
      if (!mounted) return;
      if (e.fieldError('password') != null) {
        setState(() => _passwordError = e.fieldError('password'));
      } else if (e.fieldError('verification_token') != null ||
          e.fieldError('phone') != null ||
          e.apiCode == 'conflict') {
        // Verifikasi kedaluwarsa / nomor sudah terdaftar → mulai lagi dari nomor.
        setState(() {
          _verified = null;
          _codeSent = false;
          _code.clear();
          _phoneError = _apiMessage(e);
        });
      } else {
        context.feedback.error(e, retry: _submit);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeNumber() => setState(() {
    _timer?.cancel();
    _codeSent = false;
    _verified = null;
    _code.clear();
    _codeError = null;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final verified = _verified != null;
    return OlDetailScaffold(
      title: _daftar ? 'Daftar akun pasien' : 'Lupa password',
      background: c.surface,
      context_: verified
          ? 'Langkah 3 dari 3 · Buat password'
          : _codeSent
          ? 'Langkah 2 dari 3 · Kode WhatsApp'
          : 'Langkah 1 dari 3 · Nomor HP',
      foot: [
        // Langkah 2 tanpa tombol: kode divalidasi otomatis begitu 6 digit terisi.
        if (!_codeSent)
          OlButton(
            label: 'Kirim kode lewat WhatsApp',
            loading: _busy,
            onPressed: _sendCode,
          )
        else if (verified)
          OlButton(
            label: _daftar ? 'Daftar' : 'Simpan password baru',
            loading: _busy,
            onPressed: _submit,
          ),
      ],
      children: [
        if (!_codeSent) ...[
          Text(
            _daftar
                ? 'Kami kirim kode verifikasi lewat WhatsApp. Setelah nomor terverifikasi, buat password untuk masuk.'
                : 'Kami kirim kode verifikasi lewat WhatsApp ke nomor akun Anda, lalu buat password baru.',
            style: t.body.copyWith(fontSize: 15, color: c.muted),
          ),
          OlTextField(
            label: 'Nomor HP (WhatsApp)',
            isRequired: true,
            controller: _phone,
            keyboardType: TextInputType.phone,
            hint: 'mis. 0812 3456 7890',
            error: _phoneError,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => setState(() => _phoneError = null),
            onSubmitted: (_) => _sendCode(),
          ),
        ] else ...[
          // Nomor yang sedang diverifikasi + ubah nomor.
          OlCard(
            child: Row(
              children: [
                OlIcon(
                  verified ? OlIcons.checkCircle : OlIcons.phone,
                  color: verified ? c.ok : c.muted,
                ),
                const SizedBox(width: OlSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _phone.text.trim(),
                        style: t.mono.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        verified
                            ? 'Nomor terverifikasi'
                            : 'Kode dikirim lewat WhatsApp',
                        style: t.caption.copyWith(
                          color: verified ? c.ok : c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!verified)
                  OlButton.text(
                    label: 'Ubah nomor',
                    small: true,
                    onPressed: _changeNumber,
                  ),
              ],
            ),
          ),
          if (!verified) ...[
            Text('Masukkan kode 6 digit', style: t.fieldLabel),
            OtpCodeBoxes(
              enabled: !_checking,
              controller: _code,
              focusNode: _codeFocus,
              error: _codeError != null,
              onChanged: () => setState(() => _codeError = null),
              onComplete: _checkCode,
            ),
            if (_checking)
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: c.brand,
                      ),
                    ),
                    const SizedBox(height: OlSpace.sm),
                    Text(
                      'Memverifikasi kode…',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
              )
            else if (_codeError != null)
              Text(_codeError!, style: t.body.copyWith(color: c.crit)),
            Center(
              child: _resendIn > 0
                  ? Text(
                      'Kirim ulang kode dalam 0:${_resendIn.toString().padLeft(2, '0')}',
                      style: t.body.copyWith(fontSize: 14, color: c.muted),
                    )
                  : OlButton.text(
                      label: 'Kirim ulang kode',
                      onPressed: _busy ? null : _sendCode,
                    ),
            ),
            const OlBanner(
              message:
                  'Kode berlaku 5 menit. Jangan berikan kode ini kepada siapa pun, termasuk staf klinik.',
            ),
          ] else ...[
            OlTextField(
              label: _daftar ? 'Buat password' : 'Password baru',
              isRequired: true,
              controller: _password,
              obscure: true,
              helper: 'Minimal 8 karakter.',
              error: _passwordError,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() => _passwordError = null),
            ),
            OlTextField(
              label: 'Ulangi password',
              isRequired: true,
              controller: _password2,
              obscure: true,
              error: _password2Error,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _password2Error = null),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
          ],
        ],
      ],
    );
  }
}

/// 6 kotak kode; satu TextField tersembunyi menampung isian (tempel kode juga bisa).
class OtpCodeBoxes extends StatelessWidget {
  const OtpCodeBoxes({
    super.key,
    this.enabled = true,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
    required this.onComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool error;

  /// false selama kode sedang diverifikasi.
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final code = controller.text;
    return Semantics(
      label: 'Kode 6 digit, terisi ${code.length}',
      textField: true,
      child: GestureDetector(
        onTap: focusNode.requestFocus,
        child: Stack(
          children: [
            // Field asli (transparan) di belakang kotak — menerima keyboard & tempel.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    onChanged();
                    if (v.length == 6) onComplete();
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: ListenableBuilder(
                listenable: Listenable.merge([controller, focusNode]),
                builder: (context, _) {
                  final v = controller.text;
                  return Row(
                    children: [
                      for (var i = 0; i < 6; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedContainer(
                            duration: OlMotion.of(context, OlMotion.fast),
                            height: 58,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: error
                                    ? c.crit
                                    : (focusNode.hasFocus && i == v.length
                                          ? c.brand
                                          : c.line),
                                width: focusNode.hasFocus && i == v.length
                                    ? 2
                                    : 1.5,
                              ),
                              boxShadow: focusNode.hasFocus && i == v.length
                                  ? [
                                      BoxShadow(
                                        color: c.brand.withValues(alpha: 0.12),
                                        spreadRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              i < v.length ? v[i] : '',
                              style: t.heading.copyWith(fontSize: 22),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

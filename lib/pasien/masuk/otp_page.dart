import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_session.dart';

/// PS-02 Masuk: nomor HP → kode OTP 6 digit lewat WhatsApp.
/// Slicing UI: kode apa pun diterima kecuali `000000` (contoh kode salah).
class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _sent = false;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  String get _pretty {
    final d = _digits;
    final parts = <String>[];
    for (var i = 0; i < d.length; i += 4) {
      parts.add(d.substring(i, (i + 4).clamp(0, d.length)));
    }
    return parts.join(' ');
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = true;
      _error = null;
      _code.clear();
    });
    _startTimer();
    _codeFocus.requestFocus();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (_code.text == '000000') {
      setState(() {
        _busy = false;
        _error = 'Kode salah. Periksa lagi pesan WhatsApp Anda.';
      });
      return;
    }
    ref.read(pasienSessionProvider.notifier).verified(_pretty);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    if (!_sent) {
      return OlDetailScaffold(
        title: 'Masuk',
        showBack: false,
        background: c.surface,
        foot: [
          OlButton(
            label: 'Kirim kode lewat WhatsApp',
            loading: _busy,
            onPressed: _digits.length >= 10 ? _send : null,
          ),
        ],
        children: [
          Text(
            'Masukkan nomor HP yang terdaftar di klinik. Kami kirim kode masuk lewat WhatsApp.',
            style: t.body.copyWith(fontSize: 15, color: c.muted),
          ),
          OlTextField(
            label: 'Nomor HP',
            isRequired: true,
            controller: _phone,
            hint: '0812 3456 7890',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
            ],
            error: _digits.isNotEmpty && _digits.length < 10
                ? 'Nomor HP belum lengkap — minimal 10 digit.'
                : null,
            onChanged: (_) => setState(() {}),
          ),
          Center(
            child: OlButton.text(
              label: 'Staf klinik? Masuk dengan username',
              onPressed: () {
                ref.read(pasienSessionProvider.notifier).chooseStaff();
                context.go(Routes.login);
              },
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _sent = false);
      },
      child: OlDetailScaffold(
        title: 'Masukkan kode',
        background: c.surface,
        foot: [
          OlButton(
            label: 'Verifikasi',
            loading: _busy,
            onPressed: _code.text.length == 6 ? _verify : null,
          ),
        ],
        children: [
          Text.rich(
            TextSpan(
              text: 'Kode 6 digit telah dikirim lewat WhatsApp ke ',
              children: [
                TextSpan(
                  text: _pretty,
                  style: t.mono.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.fg,
                  ),
                ),
                const TextSpan(text: '. '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => setState(() => _sent = false),
                    child: Text(
                      'Ubah nomor',
                      style: t.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.brand,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            style: t.body.copyWith(fontSize: 15, color: c.muted),
          ),
          _CodeBoxes(
            controller: _code,
            focusNode: _codeFocus,
            error: _error != null,
            onChanged: () => setState(() => _error = null),
            onComplete: _verify,
          ),
          if (_error != null)
            Text(_error!, style: t.body.copyWith(color: c.crit)),
          Center(
            child: _resendIn > 0
                ? Text.rich(
                    TextSpan(
                      text: 'Kirim ulang kode dalam ',
                      children: [
                        TextSpan(
                          text: '0:${_resendIn.toString().padLeft(2, '0')}',
                          style: t.mono.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.fg,
                          ),
                        ),
                      ],
                    ),
                    style: t.body.copyWith(fontSize: 14, color: c.muted),
                  )
                : OlButton.text(label: 'Kirim ulang kode', onPressed: _send),
          ),
          const OlBanner(
            message:
                'Kode berlaku 5 menit. Jangan berikan kode ini kepada siapa pun, termasuk staf klinik.',
          ),
        ],
      ),
    );
  }
}

/// 6 kotak kode; satu TextField tersembunyi menampung isian (tempel kode juga bisa).
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
    required this.onComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool error;
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

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-12 Ubah password & PIN.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  String _tab = 'password';
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _again = TextEditingController();
  bool _bio = true;
  bool _busy = false;
  String _pin = '';
  String? _firstPin;

  @override
  void dispose() {
    for (final c in [_old, _new, _again]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _newError => _new.text.isNotEmpty && _new.text.length < 8
      ? 'Minimal 8 karakter.'
      : null;
  String? get _againError =>
      _again.text.isNotEmpty &&
          _again.text.length >= _new.text.length &&
          _again.text != _new.text
      ? 'Password belum cocok.'
      : null;
  bool get _valid =>
      _old.text.isNotEmpty && _new.text.length >= 8 && _again.text == _new.text;

  Future<void> _savePassword() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _busy = false);
    context.feedback.success(
      'Password diganti. Perangkat lain sudah dikeluarkan.',
    );
    Navigator.of(context).maybePop();
  }

  void _pinDigit(String d) {
    if (_pin.length >= 6) return;
    setState(() => _pin += d);
    if (_pin.length < 6) return;
    if (_firstPin == null) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
      });
    } else if (_firstPin == _pin) {
      context.feedback.success('PIN baru tersimpan.');
      Navigator.of(context).maybePop();
    } else {
      context.feedback.info('PIN tidak cocok. Ulangi dari awal.');
      setState(() {
        _firstPin = null;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    final isPassword = _tab == 'password';
    return OlDetailScaffold(
      title: 'Ubah password & PIN',
      foot: isPassword
          ? [
              OlButton(
                label: 'Simpan password',
                loading: _busy,
                onPressed: _valid ? _savePassword : null,
              ),
            ]
          : const [],
      children: [
        OlSegmented<String>(
          segments: const {'password': 'Password', 'pin': 'PIN'},
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        if (isPassword) ...[
          OlTextField(
            label: 'Password lama',
            isRequired: true,
            obscure: true,
            controller: _old,
            onChanged: (_) => setState(() {}),
          ),
          OlTextField(
            label: 'Password baru',
            isRequired: true,
            obscure: true,
            controller: _new,
            error: _newError,
            onChanged: (_) => setState(() {}),
          ),
          OlTextField(
            label: 'Ulangi password baru',
            isRequired: true,
            obscure: true,
            controller: _again,
            hint: 'Ketik ulang password baru',
            error: _againError,
            onChanged: (_) => setState(() {}),
          ),
        ] else ...[
          Center(
            child: Text(
              _firstPin == null
                  ? 'Masukkan PIN baru (6 angka)'
                  : 'Ulangi PIN baru',
              style: t.heading,
            ),
          ),
          Center(child: PinDots(filled: _pin.length)),
          PinPad(
            onDigit: _pinDigit,
            onDelete: () {
              if (_pin.isNotEmpty) {
                setState(() => _pin = _pin.substring(0, _pin.length - 1));
              }
            },
          ),
        ],
        OlCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buka dengan biometrik',
                      style: t.bodyStrong.copyWith(fontSize: 15),
                    ),
                    Text(
                      'Sidik jari / wajah sebagai ganti PIN',
                      style: t.body.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              OlToggle(
                semanticLabel: 'Buka dengan biometrik',
                value: _bio,
                onChanged: (v) => setState(() => _bio = v),
              ),
            ],
          ),
        ),
        if (isPassword)
          const OlBanner(
            message:
                'Setelah password diganti, akun ini otomatis keluar dari perangkat lain.',
          ),
      ],
    );
  }
}

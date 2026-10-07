import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-07 Kunci aplikasi: PIN 6 digit / biometrik. Salah 5× → logout paksa.
class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  String _pin = '';
  int _remaining = AuthRules.maxPinAttempts;
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider.notifier);
    auth.remainingPinAttempts().then((r) {
      if (mounted) setState(() => _remaining = r);
    });
    // Tawarkan biometrik langsung bila aktif.
    if (ref.read(authProvider).biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => auth.unlockWithBiometric(),
      );
    }
  }

  Future<void> _digit(String d) async {
    if (_busy || _pin.length >= AuthRules.pinLength) return;
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length < AuthRules.pinLength) return;

    setState(() => _busy = true);
    final outcome = await ref.read(authProvider.notifier).unlockWithPin(_pin);
    if (!mounted) return;
    switch (outcome) {
      case PinOk():
        HapticFeedback.lightImpact();
      case PinWrong(:final remainingAttempts):
        HapticFeedback.heavyImpact();
        setState(() {
          _pin = '';
          _error = true;
          _remaining = remainingAttempts;
          _busy = false;
        });
      case PinForcedLogout():
        context.feedback.info(
          'PIN salah ${AuthRules.maxPinAttempts} kali. Masuk lagi dengan password.',
        );
    }
  }

  Future<void> _forgotPin() async {
    final ok = await context.feedback.confirm(
      const ConfirmSpec(
        title: 'Masuk dengan password?',
        message:
            'PIN di HP ini akan dihapus. Setelah masuk, kamu akan diminta membuat PIN baru.',
        confirmLabel: 'Masuk dengan password',
        danger: false,
      ),
    );
    if (ok) await ref.read(authProvider.notifier).forgotPin();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final s = ref.watch(authProvider);
    final user = s.user;
    // Sesaat setelah logout paksa, sebelum redirect ke login.
    if (user == null) return const Scaffold();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(34, 24, 34, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  OlAvatar(name: user.name, large: true),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text('Halo, ${user.firstName}', style: t.title),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Masukkan PIN untuk membuka aplikasi',
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 28),
                  PinDots(
                    filled: _pin.length,
                    length: AuthRules.pinLength,
                    error: _error,
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error
                          ? 'PIN salah. Sisa $_remaining percobaan'
                          : 'Sisa $_remaining percobaan',
                      style: t.body.copyWith(
                        fontSize: 13,
                        color: _error ? c.crit : c.muted,
                        fontWeight: _error ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PinPad(
                    enabled: !_busy,
                    onDigit: _digit,
                    onDelete: () {
                      if (_pin.isNotEmpty) {
                        setState(
                          () => _pin = _pin.substring(0, _pin.length - 1),
                        );
                      }
                    },
                    onBiometric: s.biometricEnabled
                        ? () => ref
                              .read(authProvider.notifier)
                              .unlockWithBiometric()
                        : null,
                  ),
                  const SizedBox(height: 20),
                  OlButton.text(
                    label: 'Lupa PIN? Masuk dengan password',
                    onPressed: _forgotPin,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

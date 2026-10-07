import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-06 Lupa password: kirim permintaan reset ke admin (→ OW-06 Persetujuan).
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _username = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty) {
      setState(() => _error = 'Username wajib diisi.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .requestPasswordReset(
            _username.text,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        context.feedback.error(
          const AppError(ErrorCode.serverError),
          retry: _submit,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  OlSpace.screen,
                  12,
                  OlSpace.screen,
                  24,
                ),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: OlBackButton(),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text('Lupa password', style: t.title),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Password direset oleh admin klinik. Kirim permintaan, lalu admin akan memberi password sementara.',
                    style: t.body.copyWith(
                      fontSize: 15,
                      color: context.ol.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OlTextField(
                    label: 'Username',
                    isRequired: true,
                    controller: _username,
                    error: _error,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: 20),
                  OlTextField(
                    label: 'Catatan untuk admin (opsional)',
                    controller: _note,
                    maxLines: 3,
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 20),
                    // Pesan selalu sama agar username tidak bisa ditebak (UM-06).
                    const OlBanner(
                      tone: OlBannerTone.ok,
                      icon: OlIcons.checkCircle,
                      message:
                          'Permintaan terkirim bila akun terdaftar. Hubungi admin bila belum ada kabar dalam 1 jam.',
                    ),
                  ],
                ],
              ),
            ),
            OlFootBar(
              children: [
                OlButton(
                  label: 'Minta reset ke admin',
                  loading: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

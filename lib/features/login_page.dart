import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth.dart';
import '../theme/app_theme.dart';
import '../ui/ui.dart';

/// Masuk — username & password dari admin (akun Laravel lama tetap bisa dipakai).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _usernameError;
  String? _passwordError;
  String? _formError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final password = _password.text;
    setState(() {
      _usernameError = username.isEmpty ? 'Username wajib diisi.' : null;
      _passwordError = password.isEmpty ? 'Password wajib diisi.' : null;
      _formError = null;
    });
    if (_usernameError != null || _passwordError != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).login(username, password);
      TextInput.finishAutofillContext();
    } on AppError catch (e) {
      if (!mounted) return;
      if (e.apiCode == 'auth_invalid' || e.apiCode == 'account_locked') {
        _password.clear();
        setState(() => _formError = e.apiMessage ?? e.message);
      } else {
        context.feedback.error(e, retry: _submit);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final expired = ref.watch(authProvider.select((s) => s.expired));
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
                'Pakai username dan password dari admin klinik.',
                style: t.body.copyWith(fontSize: 15, color: c.muted),
              ),
              const SizedBox(height: 28),
              if (expired) ...[
                const OlBanner(
                  tone: OlBannerTone.info,
                  icon: OlIcons.lock,
                  message: 'Sesi berakhir. Silakan masuk lagi.',
                ),
                const SizedBox(height: 20),
              ],
              OlTextField(
                label: 'Username',
                isRequired: true,
                controller: _username,
                error: _usernameError,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onChanged: (_) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
              ),
              const SizedBox(height: 20),
              OlTextField(
                label: 'Password',
                isRequired: true,
                controller: _password,
                obscure: true,
                error: _passwordError ?? _formError,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _busy ? null : _submit(),
                onChanged: (_) {
                  if (_passwordError != null || _formError != null) {
                    setState(() {
                      _passwordError = null;
                      _formError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              OlButton(label: 'Masuk', loading: _busy, onPressed: _submit),
              const SizedBox(height: 16),
              Text(
                'Lupa password? Minta admin mengubahnya di menu User Management.',
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

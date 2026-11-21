import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth.dart';
import '../data/klinik_api.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../ui/ui.dart';
import 'widgets.dart';

/// User Management (khusus admin, Laravel /user): daftar user, Tambah User, Ubah Password, Hapus.
class UserPage extends ConsumerStatefulWidget {
  const UserPage({super.key});

  @override
  ConsumerState<UserPage> createState() => _UserPageState();
}

class _UserPageState extends ConsumerState<UserPage> {
  int _gen = 0;

  void _reload() => setState(() => _gen++);

  Future<void> _tambah() async {
    final created = await context.feedback.formSheet<AppUser>(
      title: 'Tambah User',
      message: 'User baru masuk sebagai terapis (role user).',
      builder: (ctx, close) => _TambahUserForm(onDone: close),
    );
    if (created != null && mounted) {
      context.feedback.success('User berhasil dibuat.');
      _reload();
    }
  }

  Future<void> _ubahPassword(AppUser u) async {
    final ok = await context.feedback.formSheet<bool>(
      title: 'Ubah Password',
      message:
          '${u.name} (${u.username}). Sesi login lain milik user ini akan dikeluarkan.',
      builder: (ctx, close) => _PasswordForm(userId: u.id, onDone: close),
    );
    if (ok == true && mounted) {
      context.feedback.success('Password berhasil diubah.');
    }
  }

  Future<void> _hapus(AppUser u) async {
    final ok = await confirmHapus(
      context,
      title: 'Hapus user ${u.name}?',
      message:
          'User tidak bisa masuk lagi. Data pasien & pemeriksaan tidak ikut terhapus.',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(klinikApiProvider).hapusUser(u.id);
      if (!mounted) return;
      context.feedback.success('User berhasil dihapus.');
      _reload();
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final me = ref.watch(authProvider.select((s) => s.user?.id));
    return OlDetailScaffold(
      title: 'User Management',
      onRefresh: () async => _reload(),
      foot: [
        OlButton(label: 'Tambah User', icon: OlIcons.plus, onPressed: _tambah),
      ],
      children: [
        OlAsync<List<AppUser>>(
          key: ValueKey(_gen),
          load: () => ref.read(klinikApiProvider).users(),
          builder: (context, users, _) => [
            Text('${users.length} user', style: t.caption),
            for (final (i, u) in users.indexed)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${i + 1}. ${u.name}', style: t.bodyStrong),
                              Text(u.username, style: t.caption),
                            ],
                          ),
                        ),
                        OlTag(
                          u.role.label,
                          tone: u.isAdmin ? OlTagTone.fill : OlTagTone.brand,
                        ),
                      ],
                    ),
                    const SizedBox(height: OlSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OlButton.secondary(
                            label: 'Ubah Password',
                            small: true,
                            onPressed: () => _ubahPassword(u),
                          ),
                        ),
                        const SizedBox(width: OlSpace.sm),
                        Expanded(
                          child: OlButton(
                            label: 'Hapus',
                            small: true,
                            variant: OlButtonVariant.dangerSecondary,
                            onPressed: u.id == me ? null : () => _hapus(u),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TambahUserForm extends ConsumerStatefulWidget {
  const _TambahUserForm({required this.onDone});
  final void Function(AppUser) onDone;

  @override
  ConsumerState<_TambahUserForm> createState() => _TambahUserFormState();
}

class _TambahUserFormState extends ConsumerState<_TambahUserForm> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final e = <String, String>{
      if (_name.text.trim().isEmpty) 'name': 'Nama wajib diisi.',
      if (_username.text.trim().isEmpty) 'username': 'Username wajib diisi.',
      if (_password.text.length < 8) 'password': 'Password minimal 8 karakter.',
    };
    setState(() => _errors = e);
    if (e.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final u = await ref
          .read(klinikApiProvider)
          .tambahUser(
            name: _name.text.trim(),
            username: _username.text.trim(),
            password: _password.text,
          );
      widget.onDone(u);
    } on AppError catch (err) {
      if (!mounted) return;
      if (err.fieldErrors.isNotEmpty) {
        setState(
          () => _errors = {
            for (final f in err.fieldErrors.entries) f.key: f.value.first,
          },
        );
      } else {
        context.feedback.error(err);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OlTextField(
        label: 'Nama',
        isRequired: true,
        controller: _name,
        error: _errors['name'],
      ),
      const SizedBox(height: OlSpace.md),
      OlTextField(
        label: 'Username',
        isRequired: true,
        controller: _username,
        error: _errors['username'],
      ),
      const SizedBox(height: OlSpace.md),
      OlTextField(
        label: 'Password',
        isRequired: true,
        controller: _password,
        obscure: true,
        helper: 'Minimal 8 karakter.',
        error: _errors['password'],
      ),
      const SizedBox(height: OlSpace.lg),
      OlButton(label: 'Simpan', loading: _busy, onPressed: _save),
    ],
  );
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm({required this.userId, required this.onDone});
  final int userId;
  final void Function(bool) onDone;

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Password minimal 8 karakter.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(klinikApiProvider)
          .ubahPassword(widget.userId, _password.text);
      widget.onDone(true);
    } on AppError catch (e) {
      if (!mounted) return;
      if (e.fieldError('password') != null) {
        setState(() => _error = e.fieldError('password'));
      } else {
        context.feedback.error(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OlTextField(
        label: 'Password baru',
        isRequired: true,
        controller: _password,
        obscure: true,
        helper: 'Minimal 8 karakter.',
        error: _error,
        onSubmitted: (_) => _save(),
      ),
      const SizedBox(height: OlSpace.lg),
      OlButton(label: 'Simpan', loading: _busy, onPressed: _save),
    ],
  );
}

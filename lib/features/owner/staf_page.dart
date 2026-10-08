import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

class _Staff {
  _Staff(this.name, this.roles, this.meta, {this.active = true});
  final String name;
  final List<String> roles;
  final String meta;
  bool active;
}

const _roles = ['Terapis', 'Kasir', 'Admin klinik', 'Owner'];

/// OW-08 Kelola staf: daftar staf + peran, nonaktifkan, tambah staf
/// (password sementara dibuat otomatis, wajib diganti saat login pertama).
class StafPage extends StatefulWidget {
  const StafPage({super.key});

  @override
  State<StafPage> createState() => _StafPageState();
}

class _StafPageState extends State<StafPage> {
  final _staff = [
    _Staff('Dimas Prasetyo', ['Terapis'], 'Pusat · aktif 10 mnt lalu'),
    _Staff('Sinta Maharani', ['Kasir'], 'Pusat · aktif sekarang'),
    _Staff('Laras Ayu', ['Terapis', 'Kasir'], 'Pusat, Batu'),
    _Staff('Rudi Antono', ['Terapis'], 'sejak Agu 2026', active: false),
  ];
  static const _taken = {'dimas', 'sinta', 'laras', 'fajar', 'rudi'};

  final _name = TextEditingController(text: 'Fajar Nugraha');
  final _username = TextEditingController(text: 'fajar');
  final _formKey = GlobalKey();
  String _role = 'Terapis';

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  String? get _usernameError {
    final u = _username.text.trim().toLowerCase();
    if (u.isEmpty) return null;
    if (_taken.contains(u)) {
      return 'Username sudah dipakai. Coba "$u.${_role.toLowerCase().split(' ').first}".';
    }
    return null;
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _username.text.trim().isNotEmpty &&
      _usernameError == null;

  void _save() {
    setState(() {
      _staff.insert(
        _staff.length - 1,
        _Staff(_name.text.trim(), [_role], 'Pusat · belum login'),
      );
      _name.clear();
      _username.clear();
    });
    context.feedback.success(
      'Staf ditambahkan. Password sementara dikirim lewat WhatsApp.',
    );
  }

  Future<void> _open(_Staff s) async {
    final action = await context.feedback.sheet<String>(
      title: s.name,
      message: '${s.roles.join(', ')} · ${s.meta}',
      actions: [
        if (s.active) ...[
          const SheetAction(
            'Reset password',
            'reset',
            variant: OlButtonVariant.secondary,
          ),
          const SheetAction(
            'Nonaktifkan',
            'off',
            variant: OlButtonVariant.dangerSecondary,
          ),
        ] else
          const SheetAction('Aktifkan lagi', 'on'),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'reset':
        context.feedback.success('Password sementara dikirim ke ${s.name}.');
      case 'off':
        final ok = await context.feedback.confirm(
          ConfirmSpec(
            title: 'Nonaktifkan ${s.name}?',
            message:
                'Akun langsung keluar dari semua perangkat. Riwayat sesi & komisi tetap tersimpan.',
            confirmLabel: 'Nonaktifkan',
          ),
        );
        if (ok && mounted) {
          setState(() => s.active = false);
          context.feedback.info('${s.name} dinonaktifkan.');
        }
      case 'on':
        setState(() => s.active = true);
        context.feedback.success('${s.name} aktif lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Kelola staf',
      actions: [
        OlButton(
          label: '+ Tambah staf',
          small: true,
          expand: false,
          onPressed: () => Scrollable.ensureVisible(
            _formKey.currentContext!,
            duration: OlMotion.of(context, OlMotion.slow),
            curve: OlMotion.curve,
          ),
        ),
      ],
      children: [
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final (i, s) in _staff.indexed)
                Opacity(
                  opacity: s.active ? 1 : 0.55,
                  child: OlListItem(
                    leading: OlAvatar(name: s.name),
                    title: s.name,
                    subtitleWidget: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (s.active)
                          for (final r in s.roles) OlTag(r)
                        else
                          const OlTag('Nonaktif', tone: OlTagTone.muted),
                        Text(
                          s.meta,
                          style: t.body.copyWith(
                            fontSize: 14.5,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                    showChevron: true,
                    divider: i < _staff.length - 1,
                    onTap: () => _open(s),
                  ),
                ),
            ],
          ),
        ),
        OlOverline('TAMBAH STAF', key: _formKey),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OlTextField(
                label: 'Nama',
                isRequired: true,
                controller: _name,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: OlSpace.md),
              OlTextField(
                label: 'Username',
                isRequired: true,
                controller: _username,
                error: _usernameError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: OlSpace.md),
              Text.rich(
                TextSpan(
                  text: 'Peran',
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: c.crit),
                    ),
                  ],
                ),
                style: t.fieldLabel,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in _roles)
                    OlChip(
                      label: r,
                      selected: _role == r,
                      onTap: () => setState(() => _role = r),
                    ),
                ],
              ),
              const SizedBox(height: OlSpace.sm),
              Text(
                'Password sementara dibuat otomatis & wajib diganti saat login pertama.',
                style: t.body.copyWith(fontSize: 14, color: c.muted),
              ),
              const SizedBox(height: OlSpace.md),
              OlButton(
                label: 'Simpan staf',
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

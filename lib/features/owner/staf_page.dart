import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'persetujuan_page.dart' show showTemporaryPassword;

/// OW-08 Kelola staf (`/v1/staff`): daftar staf + peran & cabang, tambah staf (password sementara
/// dibuat server, ditampilkan sekali, wajib diganti saat login pertama), ubah peran, reset password,
/// keluarkan dari semua perangkat, nonaktifkan / aktifkan.
class StafPage extends ConsumerStatefulWidget {
  const StafPage({super.key});

  @override
  ConsumerState<StafPage> createState() => _StafPageState();
}

class _StafPageState extends ConsumerState<StafPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _formKey = GlobalKey();
  final Set<Role> _roles = {Role.terapis};
  late final Set<String> _branchIds = {
    ?ref.read(authProvider).activeBranch?.id,
  };
  Map<String, List<String>> _errors = const {};
  bool _busy = false;
  int _gen = 0;

  OneLotusApi get _api => ref.read(oneLotusApiProvider);

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _gen++);

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _username.text.trim().length >= 4 &&
      _roles.isNotEmpty &&
      _branchIds.isNotEmpty;

  void _fail(AppError e) {
    final msg = e.fieldErrors.values.expand((v) => v).firstOrNull;
    msg != null ? context.feedback.info(msg) : context.feedback.error(e);
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _errors = const {};
    });
    try {
      final (member, pw) = await _api.createStaff(
        name: _name.text.trim(),
        username: _username.text.trim().toLowerCase(),
        roles: _roles.toList(),
        branchIds: _branchIds.toList(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );
      if (!mounted) return;
      _name.clear();
      _username.clear();
      _phone.clear();
      _reload();
      await showTemporaryPassword(
        context,
        name: member.user.name,
        password: pw,
      );
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.fieldErrors);
      if (e.fieldErrors.isEmpty) context.feedback.error(e, retry: _create);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editRoles(StaffMember m) async {
    final picked = await context.feedback.formSheet<Set<Role>>(
      title: 'Peran ${m.user.name}',
      builder: (ctx, close) =>
          _RoleEditor(initial: m.user.roles.toSet(), onSave: close),
    );
    if (picked == null || !mounted) return;
    try {
      await _api.updateStaff(
        m.user.id,
        name: m.user.name,
        roles: picked.toList(),
        branchIds: [for (final b in m.user.branches) b.id],
        phone: m.phone,
      );
      if (!mounted) return;
      context.feedback.success('Peran ${m.user.name} diperbarui.');
      _reload();
    } on AppError catch (e) {
      if (mounted) _fail(e);
    }
  }

  Future<void> _open(StaffMember m) async {
    final action = await context.feedback.sheet<String>(
      title: m.user.name,
      message:
          '@${m.user.username} · ${m.user.roles.map((r) => r.label).join(', ')}',
      actions: [
        if (m.isActive) ...[
          const SheetAction(
            'Ubah peran',
            'roles',
            variant: OlButtonVariant.secondary,
          ),
          const SheetAction(
            'Reset password',
            'reset',
            variant: OlButtonVariant.secondary,
          ),
          const SheetAction(
            'Keluarkan dari semua perangkat',
            'revoke',
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
    try {
      switch (action) {
        case 'roles':
          await _editRoles(m);
        case 'reset':
          final pw = await _api.resetStaffPassword(m.user.id);
          if (mounted) {
            await showTemporaryPassword(
              context,
              name: m.user.name,
              password: pw,
            );
          }
        case 'revoke':
          await _api.revokeStaffTokens(m.user.id);
          if (mounted) {
            context.feedback.success(
              '${m.user.name} dikeluarkan dari semua perangkat.',
            );
          }
        case 'off':
          final ok = await context.feedback.confirm(
            ConfirmSpec(
              title: 'Nonaktifkan ${m.user.name}?',
              message:
                  'Akun langsung keluar dari semua perangkat. Riwayat sesi tetap tersimpan.',
              confirmLabel: 'Nonaktifkan',
            ),
          );
          if (!ok) return;
          await _api.setStaffActive(m.user.id, false);
          if (!mounted) return;
          context.feedback.info('${m.user.name} dinonaktifkan.');
          _reload();
        case 'on':
          await _api.setStaffActive(m.user.id, true);
          if (!mounted) return;
          context.feedback.success('${m.user.name} aktif lagi.');
          _reload();
      }
    } on AppError catch (e) {
      if (mounted) _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final myBranches = ref.watch(
      authProvider.select((a) => a.user?.branches ?? const <Branch>[]),
    );
    String? err(String f) => _errors[f]?.firstOrNull;
    void touch(String _) => setState(() {});
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
        OlAsync<List<StaffMember>>(
          key: ValueKey(_gen),
          load: () => _api.staff(),
          builder: (context, list, _) => [
            OlCard(
              padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
              child: Column(
                children: [
                  for (final (i, m) in list.indexed)
                    Opacity(
                      opacity: m.isActive ? 1 : 0.55,
                      child: OlListItem(
                        leading: OlAvatar(name: m.user.name),
                        title: m.user.name,
                        subtitleWidget: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (m.isActive)
                              for (final r in m.user.roles) OlTag(r.label)
                            else
                              const OlTag('Nonaktif', tone: OlTagTone.muted),
                            Text(
                              [
                                m.user.branches.map((b) => b.name).join(', '),
                                if (m.lastLoginAt != null)
                                  'login ${Fmt.dateNoDay(m.lastLoginAt!)}'
                                else
                                  'belum login',
                              ].join(' · '),
                              style: t.caption,
                            ),
                          ],
                        ),
                        showChevron: true,
                        divider: i < list.length - 1,
                        onTap: () => _open(m),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        OlCard(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tambah staf', style: t.heading),
              const SizedBox(height: OlSpace.md),
              OlTextField(
                label: 'Nama',
                isRequired: true,
                controller: _name,
                error: err('name'),
                onChanged: touch,
              ),
              const SizedBox(height: OlSpace.md),
              OlTextField(
                label: 'Username',
                isRequired: true,
                controller: _username,
                helper:
                    '4–30 karakter: huruf kecil, angka, titik. Mis. fajar.terapis',
                error: err('username'),
                onChanged: touch,
              ),
              const SizedBox(height: OlSpace.md),
              OlTextField(
                label: 'Nomor HP',
                controller: _phone,
                keyboardType: TextInputType.phone,
                error: err('phone'),
              ),
              const SizedBox(height: OlSpace.md),
              Text('Peran *', style: t.fieldLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: OlSpace.sm,
                children: [
                  for (final r in Role.values)
                    OlChip(
                      label: r.label,
                      selected: _roles.contains(r),
                      onTap: () => setState(
                        () => _roles.contains(r)
                            ? _roles.remove(r)
                            : _roles.add(r),
                      ),
                    ),
                ],
              ),
              if (err('roles') != null)
                Text(err('roles')!, style: t.caption.copyWith(color: c.crit)),
              const SizedBox(height: OlSpace.md),
              Text('Cabang *', style: t.fieldLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: OlSpace.sm,
                children: [
                  for (final b in myBranches)
                    OlChip(
                      label: b.name,
                      selected: _branchIds.contains(b.id),
                      onTap: () => setState(
                        () => _branchIds.contains(b.id)
                            ? _branchIds.remove(b.id)
                            : _branchIds.add(b.id),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: OlSpace.lg),
              OlButton(
                label: 'Simpan & buat password sementara',
                loading: _busy,
                onPressed: _canSave && !_busy ? _create : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleEditor extends StatefulWidget {
  const _RoleEditor({required this.initial, required this.onSave});
  final Set<Role> initial;
  final ValueChanged<Set<Role>> onSave;

  @override
  State<_RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends State<_RoleEditor> {
  late final Set<Role> _roles = {...widget.initial};

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: OlSpace.sm,
        children: [
          for (final r in Role.values)
            OlChip(
              label: r.label,
              selected: _roles.contains(r),
              onTap: () => setState(
                () => _roles.contains(r) ? _roles.remove(r) : _roles.add(r),
              ),
            ),
        ],
      ),
      const SizedBox(height: OlSpace.lg),
      OlButton(
        label: 'Simpan',
        onPressed: _roles.isEmpty ? null : () => widget.onSave({..._roles}),
      ),
    ],
  );
}

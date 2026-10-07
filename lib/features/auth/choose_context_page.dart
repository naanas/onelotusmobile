import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import '../../data/models/staff_user.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Ada aktivitas yang mencegah ganti cabang (sesi Berjalan / pembayaran menunggu milik akun ini).
/// TODO(tahap-4): isi dari repository sesi & tagihan.
final hasBlockingActivityProvider = Provider<bool>((ref) => false);

/// UM-08 Pilih cabang & peran. Dipakai setelah login (tanpa tombol kembali) dan dari Akun.
class ChooseContextPage extends ConsumerStatefulWidget {
  const ChooseContextPage({super.key});

  @override
  ConsumerState<ChooseContextPage> createState() => _ChooseContextPageState();
}

class _ChooseContextPageState extends ConsumerState<ChooseContextPage> {
  late Role _role;
  late Branch _branch;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(authProvider);
    _role = s.activeRole ?? s.user!.roles.first;
    _branch = s.activeBranch ?? s.user!.branches.first;
  }

  Future<void> _submit() async {
    final s = ref.read(authProvider);
    final changingBranch = s.activeBranch != null && s.activeBranch != _branch;
    if (changingBranch && ref.read(hasBlockingActivityProvider)) {
      context.feedback.info(
        'Selesaikan sesi Berjalan atau pembayaran yang menunggu dulu.',
      );
      return;
    }
    setState(() => _busy = true);
    await ref.read(authProvider.notifier).chooseContext(_role, _branch);
    if (!mounted) return;
    // Dari Akun: redirect tidak berlaku, jadi pindah ke beranda peran baru secara eksplisit.
    context.go(Routes.home(_role));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final s = ref.watch(authProvider);
    final user = s.user;
    if (user == null) return const Scaffold();
    final fromAccount = s.phase == AuthPhase.ready;
    final blocked = ref.watch(hasBlockingActivityProvider);

    final body = <Widget>[
      if (user.branches.length > 1) ...[
        Text('CABANG', style: t.overline),
        const SizedBox(height: 12),
        OlRadioList<Branch>(
          value: _branch,
          onChanged: (b) => setState(() => _branch = b),
          options: [
            for (final b in user.branches)
              OlRadioOption(
                value: b,
                title: b.name,
                subtitle: b.address,
                icon: OlIcons.branch,
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
      if (user.roles.length > 1) ...[
        Text('PERAN', style: t.overline),
        const SizedBox(height: 12),
        OlRadioList<Role>(
          value: _role,
          onChanged: (r) => setState(() => _role = r),
          options: [
            for (final r in user.roles)
              OlRadioOption(value: r, title: r.label, subtitle: r.description),
          ],
        ),
        const SizedBox(height: 16),
      ],
      if (user.branches.length > 1)
        OlBanner(
          tone: blocked ? OlBannerTone.crit : OlBannerTone.warn,
          message:
              'Tidak bisa ganti cabang selama ada sesi Berjalan atau pembayaran yang masih menunggu.',
        ),
    ];

    final button = OlButton(
      label: 'Masuk sebagai ${_role == Role.kasir ? 'Kasir' : _role.label}',
      loading: _busy,
      onPressed: _submit,
    );

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
                  if (fromAccount)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: OlBackButton(),
                    )
                  else
                    const SizedBox(height: 36),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text('Pilih cabang & peran', style: t.title),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Menu dan data menyesuaikan pilihanmu.',
                    style: t.body.copyWith(
                      fontSize: 15,
                      color: context.ol.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...body,
                ],
              ),
            ),
            OlFootBar(children: [button]),
          ],
        ),
      ),
    );
  }
}

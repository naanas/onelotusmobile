import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/intake/intake_repository.dart';
import '../../data/models/models.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// KS-02 Intake QR: QR form WB-01 untuk discan pasien + daftar "Baru masuk" (diperbarui tiap 10 detik).
/// Ketuk kiriman → verifikasi di KS-04 → pasien dibuat server (nomor & cek ganda).
class IntakePage extends ConsumerStatefulWidget {
  const IntakePage({super.key});

  static const refreshEvery = Duration(seconds: 10);

  @override
  ConsumerState<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends ConsumerState<IntakePage> {
  IntakeLink? _link;
  List<IntakeSummary>? _items;
  AppError? _error;
  bool _rotating = false;
  Timer? _timer;

  PatientIntakeRepository get _repo =>
      ref.read(patientIntakeRepositoryProvider);
  Branch? get _branch => ref.read(authProvider).activeBranch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _timer = Timer.periodic(IntakePage.refreshEvery, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final branch = _branch;
    if (branch == null) return;
    setState(() => _error = null);
    try {
      final link = await _repo.link(branch.id);
      final items = await _repo.pending(branch.id);
      if (!mounted) return;
      setState(() {
        _link = link;
        _items = items;
      });
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Pembaruan diam-diam; gagal → data lama tetap tampil.
  Future<void> _refresh() async {
    final branch = _branch;
    if (branch == null || _link == null) return;
    try {
      final items = await _repo.pending(branch.id);
      if (mounted) setState(() => _items = items);
    } on AppError {
      // Coba lagi di putaran berikutnya.
    }
  }

  Future<void> _rotate() async {
    final branch = _branch;
    if (branch == null) return;
    final ok = await context.feedback.confirm(
      const ConfirmSpec(
        title: 'Ganti QR intake?',
        message:
            'QR lama langsung tidak berlaku. Pasien yang sedang mengisi form lama perlu scan ulang.',
        confirmLabel: 'Ganti QR',
        danger: false,
      ),
    );
    if (!ok || !mounted) return;
    setState(() => _rotating = true);
    try {
      final link = await _repo.rotateLink(branch.id);
      if (!mounted) return;
      setState(() => _link = link);
      context.feedback.info('QR baru dibuat. QR lama tidak berlaku.');
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    } finally {
      if (mounted) setState(() => _rotating = false);
    }
  }

  Future<void> _open(IntakeSummary item) async {
    await context.push(
      Uri(
        path: Routes.kasirPasienForm,
        queryParameters: {'intake': item.id},
      ).toString(),
    );
    if (mounted) unawaited(_refresh());
  }

  String _subtitle(IntakeSummary i) {
    final now = DateTime.now();
    final sameDay =
        i.createdAt.year == now.year &&
        i.createdAt.month == now.month &&
        i.createdAt.day == now.day;
    final when = sameDay
        ? 'Masuk ${Fmt.time(i.createdAt)}'
        : 'Masuk ${Fmt.dayShort(i.createdAt)} ${Fmt.time(i.createdAt)}';
    return [
      '${i.queueLabel} · $when',
      if (i.complaint.isNotEmpty) i.complaint,
      i.bodyComplete ? 'TB/BB lengkap' : 'TB/BB belum diisi',
      if (i.attachmentCount > 0) '${i.attachmentCount} foto',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final branch = ref.watch(authProvider).activeBranch;
    final link = _link;
    final items = _items;

    return OlDetailScaffold(
      title: 'Intake pasien baru',
      close: true,
      actions: [
        TextButton(
          onPressed: () => context.push(Routes.kasirPasienForm),
          style: TextButton.styleFrom(
            foregroundColor: c.brand,
            textStyle: t.button,
          ),
          child: const Text('Input manual'),
        ),
      ],
      children: [
        if (_error != null && link == null)
          _ErrorCard(error: _error!, onRetry: _load)
        else ...[
          OlCard(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                if (link == null || _rotating)
                  const Skeleton(width: 220, height: 220, radius: 24)
                else
                  _QrBox(url: link.url),
                const SizedBox(height: 14),
                Text('Minta pasien scan QR ini', style: t.heading),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Form intake · ${branch?.name ?? '-'} · ',
                      style: t.body.copyWith(color: c.muted),
                    ),
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: link == null || _rotating ? null : _rotate,
                        child: Text(
                          'Ganti QR',
                          style: t.bodyStrong.copyWith(color: c.brand),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Baru masuk',
                  style: t.heading.copyWith(fontSize: 17),
                ),
              ),
              const SyncIndicator(
                status: SyncSaving(),
                label: 'Diperbarui langsung',
              ),
            ],
          ),
          if (items == null)
            const OlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 180, height: 16),
                  SizedBox(height: 10),
                  Skeleton(height: 12),
                ],
              ),
            )
          else if (items.isEmpty)
            OlCard(
              child: Text(
                'Belum ada formulir masuk. Kiriman pasien muncul di sini otomatis.',
                style: t.body.copyWith(color: c.muted),
              ),
            )
          else
            OlCard(
              padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
              child: Column(
                children: [
                  for (final (n, i) in items.indexed)
                    OlListItem(
                      leading: OlAvatar(name: i.name),
                      title: i.name,
                      subtitle: _subtitle(i),
                      trailing: i.stale
                          ? const OlTag('>24 jam', tone: OlTagTone.crit)
                          : const OlTag('Verifikasi'),
                      divider: n < items.length - 1,
                      onTap: () => _open(i),
                    ),
                ],
              ),
            ),
          Text(
            'Nomor pasien dibuat server saat data disimpan. Sistem mengecek data ganda (nama + tanggal lahir, atau nomor HP) sebelum menyimpan.',
            style: t.body.copyWith(color: c.muted),
          ),
        ],
      ],
    );
  }
}

class _QrBox extends StatelessWidget {
  const _QrBox({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Semantics(
      label: 'Kode QR form intake untuk dipindai pasien',
      image: true,
      child: Container(
        width: 220,
        height: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.line, width: 1.5),
        ),
        child: QrImageView(
          data: url,
          padding: EdgeInsets.zero,
          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: c.fg),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: c.fg,
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final AppError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return OlCard(
      child: Column(
        children: [
          Text(
            error.type == ErrorCode.networkOffline
                ? 'Kamu sedang offline. QR & kiriman intake butuh koneksi.'
                : 'Data intake belum bisa dimuat. Coba beberapa saat lagi.',
            style: t.body.copyWith(color: context.ol.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OlButton(label: 'Coba lagi', expand: false, onPressed: onRetry),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/billing_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_forms.dart';
import 'owner_widgets.dart';

const reportLabels = {
  'revenue': 'Pendapatan',
  'top_services': 'Layanan terlaris',
  'therapist_performance': 'Kinerja terapis',
  'retention': 'Retensi pasien',
  'home_visit': 'Home visit',
  'packages': 'Paket',
  'receivables': 'Piutang',
  'refunds_discounts': 'Refund & diskon',
  'patients': 'Daftar pasien',
  'commissions': 'Komisi',
};

/// OW-05 Ekspor laporan: jenis, rentang tanggal, cabang, format. Data kontak
/// pasien hanya bila diaktifkan + alasan (UU PDP). Setiap ekspor masuk audit log.
class EksporPage extends ConsumerStatefulWidget {
  const EksporPage({super.key, this.report});
  final String? report;

  @override
  ConsumerState<EksporPage> createState() => _EksporPageState();
}

class _EksporPageState extends ConsumerState<EksporPage> {
  late String _report = widget.report ?? 'revenue';
  String _format = 'xlsx';
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();
  bool _allBranches = true;
  bool _contacts = false;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _url;
  Timer? _poll;

  void _setRange(DateTime from, DateTime to) => setState(() {
    _from = from;
    _to = to;
  });

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_contacts && _reason.text.trim().isEmpty) return context.feedback.info('Tulis alasan menyertakan kontak pasien.');
    final api = ref.read(billingApiProvider);
    setState(() {
      _busy = true;
      _url = null;
    });
    final job = await runApi(
      context,
      () => api.export({
        'report': _report,
        'format': _format,
        'from': isoDay(_from),
        'to': isoDay(_to),
        'branch_id': _allBranches ? null : ref.read(authProvider).activeBranch?.id,
        if (_report == 'patients') 'include_contacts': _contacts,
        if (_contacts) 'reason': _reason.text.trim(),
      }),
    );
    if (!mounted) return;
    if (job == null) return setState(() => _busy = false);
    if (job.url != null) {
      setState(() {
        _busy = false;
        _url = job.url;
      });
      return;
    }
    var tries = 0;
    _poll = Timer.periodic(const Duration(seconds: 2), (t) async {
      tries++;
      try {
        final s = await api.exportStatus(job.id);
        if (!mounted) return t.cancel();
        if (s.status == 'ready' || s.url != null) {
          t.cancel();
          setState(() {
            _busy = false;
            _url = s.url;
          });
        } else if (s.status == 'failed' || tries > 30) {
          t.cancel();
          setState(() => _busy = false);
          context.feedback.info('Ekspor gagal dibuat. Coba lagi.');
        }
      } catch (e) {
        t.cancel();
        if (mounted) {
          setState(() => _busy = false);
          showApiError(context, e);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final now = DateTime.now();
    return OlDetailScaffold(
      title: 'Ekspor',
      foot: [OlButton(label: 'Buat file', icon: OlIcons.download, loading: _busy, onPressed: _start)],
      children: [
        OlSelectField<String>(
          label: 'Laporan',
          sheetTitle: 'Jenis laporan',
          value: _report,
          options: reportLabels,
          onChanged: (v) => setState(() => _report = v),
        ),
        Wrap(
          spacing: OlSpace.sm,
          children: [
            OlChip(label: 'Bulan ini', small: true, onTap: () => _setRange(DateTime(now.year, now.month), now)),
            OlChip(
              label: 'Bulan lalu',
              small: true,
              onTap: () => _setRange(DateTime(now.year, now.month - 1), DateTime(now.year, now.month, 0)),
            ),
            OlChip(label: '30 hari', small: true, onTap: () => _setRange(now.subtract(const Duration(days: 29)), now)),
          ],
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              OwDateRow(label: 'Dari', value: _from, onChanged: (d) => setState(() => _from = d)),
              OwDateRow(label: 'Sampai', value: _to, first: _from, onChanged: (d) => setState(() => _to = d)),
            ],
          ),
        ),
        OlSegmented<String>(segments: const {'xlsx': 'Excel', 'pdf': 'PDF'}, value: _format, onChanged: (v) => setState(() => _format = v)),
        OwToggleRow(label: 'Semua cabang', value: _allBranches, onChanged: (v) => setState(() => _allBranches = v)),
        if (_report == 'patients') ...[
          OwToggleRow(
            label: 'Sertakan nomor HP & alamat',
            subtitle: 'Data pribadi (UU PDP) — wajib alasan, tercatat di audit log',
            value: _contacts,
            onChanged: (v) => setState(() => _contacts = v),
          ),
          if (_contacts) OlTextField(label: 'Alasan', controller: _reason, isRequired: true),
        ],
        if (_url != null)
          OlCard(
            variant: OlCardVariant.now,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('File siap', style: t.heading),
                Text('Tautan berlaku sementara. Buka di browser untuk mengunduh.', style: t.caption.copyWith(color: c.muted)),
                const SizedBox(height: OlSpace.md),
                OlButton.secondary(
                  label: 'Salin tautan unduhan',
                  icon: OlIcons.copy,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _url!));
                    context.feedback.success('Tautan disalin.');
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

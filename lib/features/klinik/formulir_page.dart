import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'intake_xray.dart';
import 'klinik_api.dart';
import 'klinik_models.dart';
import 'pager.dart';
import 'widgets.dart';

final _jam = DateFormat('EEE, d MMM yyyy · HH:mm', 'id');
final _rp = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);

String _when(DateTime? d) => d == null ? '-' : _jam.format(d.toLocal());

/// Formulir (Laravel: hasil Google Form). Kiriman form web (onelotusweb) & booking aplikasi pasien yang sudah
/// dibayar menunggu persetujuan terapis/admin. Setujui → nomor pasien terbit → Tambah Pemeriksaan
/// dengan keluhan dari formulir.
class FormulirPage extends ConsumerStatefulWidget {
  const FormulirPage({super.key});

  @override
  ConsumerState<FormulirPage> createState() => _FormulirPageState();
}

class _FormulirPageState extends ConsumerState<FormulirPage> with VisibleReload {
  late final _pager = Pager<Formulir>((page) => ref.read(klinikApiProvider).formulir(page: page))..reload();

  @override
  void onVisibleAgain() => _pager.reload();

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _open(Formulir f) async {
    await context.push(Routes.klinikFormulirDetail(f.id), extra: f);
    if (mounted) _pager.reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return InfiniteScroll(
      onEnd: _pager.more,
      child: ListenableBuilder(
        listenable: _pager,
        builder: (context, _) {
          final p = _pager;
          final baru = [for (final f in p.items) if (f.menunggu) f];
          final lunas = [for (final f in p.items) if (!f.menunggu) f];
          return OlPageBody(
            pinnedHeader: true,
            header: const OlAppHeader(title: 'Formulir'),
            onRefresh: () {
              ref.read(klinikApiProvider).cache.expire('/v1/klinik/formulir');
              return _pager.reload();
            },
            children: [
              Text(
                'Pendaftaran dari form web dan booking aplikasi pasien. Setujui supaya pasien '
                'mendapat nomor pasien dan masuk Data Pasien.',
                style: t.body.copyWith(color: context.ol.muted),
              ),
              if (p.loadedOnce && p.total == 0 && p.error == null)
                const OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptyInbox,
                    title: 'Tidak ada formulir baru',
                    message: 'Kiriman form web dan booking aplikasi yang sudah dibayar akan muncul di sini.',
                  ),
                ),
              if (p.total > 0) Text('${p.total} menunggu persetujuan', style: t.caption),
              if (baru.isNotEmpty) ...[
                const OlSectionHeader(title: 'Jadwal belum diterima'),
                for (final f in baru) _FormulirCard(data: f, onTap: () => _open(f)),
              ],
              if (lunas.isNotEmpty) ...[
                const OlSectionHeader(title: 'Sudah terjadwal'),
                for (final f in lunas) _FormulirCard(data: f, onTap: () => _open(f)),
              ],
              PagerFooter(pager: p),
            ],
          );
        },
      ),
    );
  }
}

class _FormulirCard extends StatelessWidget {
  const _FormulirCard({required this.data, required this.onTap});
  final Formulir data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    final f = data;
    final nomor = f.pasien?.nomor;
    return OlCard(
      onTap: onTap,
      semanticLabel: 'Formulir ${f.nama}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OlAvatar(name: f.nama),
              const SizedBox(width: OlSpace.md),
              Expanded(child: Text(f.nama, style: t.heading)),
              OlTag(
                f.dariAplikasi ? 'Aplikasi' : 'Form Web',
                tone: f.dariAplikasi ? OlTagTone.brand : OlTagTone.outline,
              ),
            ],
          ),
          const SizedBox(height: OlSpace.sm),
          const SizedBox(height: 2),
          Text(
            nomor == null ? 'Pasien baru · nomor terbit setelah disetujui' : nomorPasien(nomor),
            style: t.caption.copyWith(
              color: nomor == null ? c.brand : c.muted,
              fontWeight: nomor == null ? FontWeight.w700 : null,
            ),
          ),
          Text('Dikirim ${_when(f.dikirim)}', style: t.caption),
          Text('${f.layanan} · ${_when(f.jadwal)}', style: t.caption),
          if (f.intake.keluhan != null) ...[
            const SizedBox(height: OlSpace.xs),
            Text(
              f.intake.keluhan!,
              style: t.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: OlSpace.xs),
          Text(
            f.lunas
                ? 'Lunas${f.total == null ? '' : ' · ${_rp.format(f.total)}'}'
                : (f.menunggu ? 'Tanpa pembayaran online · jadwal belum diterima' : 'Tanpa pembayaran online'),
            style: t.caption.copyWith(color: f.lunas ? c.ok : c.muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Detail satu kiriman: data diri, keluhan, rontgen, lalu Setujui / Tolak.
class FormulirDetailPage extends ConsumerStatefulWidget {
  const FormulirDetailPage({super.key, required this.id, this.initial});
  final String id;
  final Formulir? initial;

  @override
  ConsumerState<FormulirDetailPage> createState() => _FormulirDetailPageState();
}

class _FormulirDetailPageState extends ConsumerState<FormulirDetailPage> {
  bool _busy = false;
  late Future<Formulir> _future = _load();

  Future<Formulir> _load() async => widget.initial ?? ref.read(klinikApiProvider).formulirDetail(widget.id);

  Future<void> _setujui(Formulir f) async {
    int? nomor;
    if (f.pasien?.nomor == null) {
      // Laravel: nomor otomatis (terbesar + 1); staf boleh mengisi nomor sendiri.
      final pick = await context.feedback.formSheet<_NomorPilihan>(
        title: 'Setujui ${f.nama}?',
        message: 'Pasien mendapat nomor pasien dan masuk Data Pasien.',
        builder: (ctx, close) => _NomorForm(onDone: close),
      );
      if (pick == null || !mounted) return;
      nomor = pick.nomor;
    } else {
      final ok = await context.feedback.confirm(
        ConfirmSpec(
          title: 'Setujui ${f.nama}?',
          message: '${nomorPasien(f.pasien!.nomor)} sudah terdaftar. Lanjut isi pemeriksaan.',
          confirmLabel: 'Setujui',
        ),
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(klinikApiProvider).setujui(f.id, nomor: nomor);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.feedback.success('Disetujui · ${nomorPasien(r.pasien.nomor)}');
      final i = r.intake;
      context.pushReplacement(
        Routes.klinikTambahPemeriksaan(r.pasien.id, lanjutDetail: true),
        extra: PemeriksaanDraft(
          keluhan: [i.keluhan, if (i.catatan != null) 'Catatan: ${i.catatan}'].whereType<String>().join('\n'),
          penyebab: i.penyebab,
          lamaCedera: i.lamaCedera,
          hasilRontgen: i.rontgen,
          bookingId: f.id,
        ),
      );
    } on AppError catch (e) {
      if (!mounted) return;
      final msg = e.fieldError('nomor');
      if (msg != null) {
        context.feedback.info(msg);
      } else {
        context.feedback.error(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tolak(Formulir f) async {
    final alasan = await context.feedback.formSheet<String>(
      title: 'Tolak ${f.nama}?',
      message: 'Pasien diberi tahu bahwa booking tidak dapat diterima.',
      builder: (ctx, close) => _AlasanForm(onDone: close),
    );
    if (alasan == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(klinikApiProvider).tolak(f.id, alasan);
      if (!mounted) return;
      context.feedback.success('Formulir ditolak.');
      context.pop(true);
    } on AppError catch (e) {
      if (mounted) context.feedback.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Formulir>(
      future: _future,
      builder: (context, snap) {
        final f = snap.data;
        return OlDetailScaffold(
          title: 'Formulir',
          foot: f == null
              ? const []
              : [
                  OlButton(label: 'Setujui', loading: _busy, onPressed: () => _setujui(f)),
                  if (f.menunggu)
                    OlButton(
                      label: 'Tolak',
                      variant: OlButtonVariant.dangerSecondary,
                      onPressed: _busy ? null : () => _tolak(f),
                    ),
                ],
          children: [
            if (snap.hasError)
              OlErrorCard(
                message: snap.error is AppError ? (snap.error as AppError).message : 'Formulir gagal dimuat.',
                onRetry: () => setState(() => _future = _load()),
              )
            else if (f == null)
              const OlLoadingCard()
            else
              ..._body(context, f),
          ],
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, Formulir f) {
    final t = context.olText;
    final p = f.pasien;
    final i = f.intake;
    final diri = <(String, String)>[
      ('Nomor Pasien', p?.nomor == null ? 'Belum ada (terbit setelah disetujui)' : '${p!.nomor}'),
      ('Nama', f.nama),
      if (p != null) ...[
        (
          'Tanggal Lahir',
          [if (p.tempatLahir != null) p.tempatLahir!, tgl(p.ttl)].join(', '),
        ),
        if (p.tlp != null) ('Nomor Telepon', p.tlp!),
        ('Alamat', p.alamat ?? '-'),
        ('Jenis Kelamin', genderLabel(p.gender)),
        ('Instansi', p.instansi ?? '-'),
        ('Hobi / Kegiatan', p.hobi ?? '-'),
        ('Berat Badan', p.bb == null ? '-' : '${fmtNum(p.bb!)} kg'),
        ('Tinggi Badan', p.tb == null ? '-' : '${fmtNum(p.tb!)} cm'),
      ],
    ];
    final kirim = <(String, String)>[
      ('Sumber', f.dariAplikasi ? 'Aplikasi pasien' : 'Form web'),
      ('Dikirim', _when(f.dikirim)),
      ('Layanan', f.layanan),
      ('Jadwal', '${_when(f.jadwal)}${f.homeVisit ? ' · Home visit' : ''}'),
      (
        'Pembayaran',
        f.lunas ? 'Lunas${f.total == null ? '' : ' · ${_rp.format(f.total)}'}' : 'Tanpa pembayaran online',
      ),
      if (f.menunggu) ('Status jadwal', 'Belum diterima — diterima otomatis saat disetujui'),
    ];
    Widget card(String title, List<(String, String)> rows) => OlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: t.heading),
          const SizedBox(height: OlSpace.sm),
          for (final (n, r) in rows.indexed)
            OlInfoRow(label: r.$1, value: r.$2, divider: n < rows.length - 1),
        ],
      ),
    );
    return [
      card('Data Diri', diri),
      OlCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Keluhan', style: t.heading),
            const SizedBox(height: OlSpace.xs),
            Text(i.keluhan ?? '-', style: t.body),
            LabelValue('Penyebab', i.penyebab),
            LabelValue('Lama cedera', i.lamaCedera),
            LabelValue('Rontgen', i.rontgen),
            LabelValue('Catatan', i.catatan),
          ],
        ),
      ),
      if (f.fileRontgen > 0) IntakeXray.booking(bookingId: f.id),
      card('Kiriman', kirim),
    ];
  }
}

class _NomorPilihan {
  const _NomorPilihan(this.nomor);
  final int? nomor;
}

class _NomorForm extends StatefulWidget {
  const _NomorForm({required this.onDone});
  final void Function(_NomorPilihan) onDone;

  @override
  State<_NomorForm> createState() => _NomorFormState();
}

class _NomorFormState extends State<_NomorForm> {
  final _nomor = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nomor.dispose();
    super.dispose();
  }

  void _save() {
    final v = _nomor.text.trim();
    if (v.isNotEmpty && (int.tryParse(v) ?? 0) <= 0) {
      setState(() => _error = 'Nomor pasien harus berupa angka.');
      return;
    }
    widget.onDone(_NomorPilihan(v.isEmpty ? null : int.parse(v)));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OlTextField(
        label: 'Nomor pasien',
        controller: _nomor,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        helper: 'Kosongkan untuk nomor otomatis (nomor terbesar + 1).',
        error: _error,
        onSubmitted: (_) => _save(),
      ),
      const SizedBox(height: OlSpace.lg),
      OlButton(label: 'Setujui', onPressed: _save),
    ],
  );
}

class _AlasanForm extends StatefulWidget {
  const _AlasanForm({required this.onDone});
  final void Function(String) onDone;

  @override
  State<_AlasanForm> createState() => _AlasanFormState();
}

class _AlasanFormState extends State<_AlasanForm> {
  final _alasan = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  void _save() {
    final v = _alasan.text.trim();
    if (v.isEmpty) {
      setState(() => _error = 'Tulis alasan penolakan.');
      return;
    }
    widget.onDone(v);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OlTextField(
        label: 'Alasan',
        controller: _alasan,
        maxLines: 2,
        hint: 'Mis. jadwal penuh, silakan pilih jam lain',
        error: _error,
      ),
      const SizedBox(height: OlSpace.lg),
      OlButton(
        label: 'Tolak',
        variant: OlButtonVariant.danger,
        onPressed: _save,
      ),
    ],
  );
}

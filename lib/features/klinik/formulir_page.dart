import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'intake_xray.dart';
import 'k_ui.dart';
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
  void onVisibleAgain() => _pager.refresh();

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _open(Formulir f) async {
    await context.push(Routes.klinikFormulirDetail(f.id), extra: f);
    if (mounted) _pager.refresh();
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
          final baru = [
            for (final f in p.items)
              if (f.menunggu) f,
          ];
          final lunas = [
            for (final f in p.items)
              if (!f.menunggu) f,
          ];
          return OlPageBody(
            pinnedHeader: true,
            backToTop: true,
            header: const OlAppHeader(title: 'Formulir'),
            onRefresh: () {
              ref.read(klinikApiProvider).cache.expire('/v1/klinik/formulir');
              return _pager.reload();
            },
            children: [
              KHero(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (p.total > 0) const KPulseDot(color: Color(0xFFFFC56B)),
                        if (p.total > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            p.total > 0 ? 'Perlu persetujuan' : 'Semua formulir beres',
                            style: t.caption.copyWith(
                              color: Colors.white.withValues(alpha: .8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OlSpace.md),
                    KStatRow(
                      light: true,
                      children: [
                        KStat(value: p.loadedOnce ? baru.length : null, label: 'Jadwal belum diterima', light: true),
                        KStat(value: p.loadedOnce ? lunas.length : null, label: 'Sudah terjadwal', light: true),
                      ],
                    ),
                    const SizedBox(height: OlSpace.md),
                    Text(
                      'Dari form web & aplikasi pasien. Setujui supaya pasien mendapat nomor dan masuk Data Pasien.',
                      style: t.caption.copyWith(color: Colors.white.withValues(alpha: .75), height: 1.4),
                    ),
                  ],
                ),
              ),
              if (p.loadedOnce && p.total == 0 && p.error == null)
                const OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptyInbox,
                    title: 'Tidak ada formulir baru',
                    message: 'Kiriman form web dan booking aplikasi yang sudah dibayar akan muncul di sini.',
                  ),
                ),
              if (baru.isNotEmpty) ...[
                const OlSectionHeader(title: 'Jadwal belum diterima'),
                OlAnimatedItems(
                  children: [
                    for (final f in baru)
                      KeyedSubtree(
                        key: ValueKey(f.id),
                        child: _FormulirCard(data: f, onTap: () => _open(f)),
                      ),
                  ],
                ),
              ],
              if (lunas.isNotEmpty) ...[
                const OlSectionHeader(title: 'Sudah terjadwal'),
                OlAnimatedItems(
                  children: [
                    for (final f in lunas)
                      KeyedSubtree(
                        key: ValueKey(f.id),
                        child: _FormulirCard(data: f, onTap: () => _open(f)),
                      ),
                  ],
                ),
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
    final accent = f.menunggu ? c.warn : c.ok;
    return OlCard(
      onTap: onTap,
      semanticLabel: 'Formulir ${f.nama}',
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OlRadius.card),
        child: Stack(
          children: [
            Positioned(left: 0, top: 0, bottom: 0, width: 5, child: ColoredBox(color: accent)),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, OlSpace.lg, OlSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        KAvatar(name: f.nama, size: 42),
                        const SizedBox(width: OlSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.nama,
                                style: t.bodyStrong.copyWith(fontSize: 15.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                nomor == null ? 'Pasien baru' : nomorPasien(nomor),
                                style: t.caption.copyWith(
                                  color: nomor == null ? c.brand : c.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        KPill(
                          f.dariAplikasi ? 'Aplikasi' : 'Form Web',
                          icon: f.dariAplikasi ? OlIcons.user : OlIcons.attach,
                          tone: f.dariAplikasi ? KPillTone.brand : KPillTone.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: OlSpace.md),
                    KMeta(OlIcons.package, f.layanan),
                    KMeta(
                      f.homeVisit ? OlIcons.homeVisit : OlIcons.calendar,
                      '${_when(f.jadwal)}${f.homeVisit ? ' · Home visit' : ''}',
                      color: c.fg,
                    ),
                    if (f.intake.keluhan != null) ...[
                      const SizedBox(height: OlSpace.md),
                      KQuote(f.intake.keluhan!, maxLines: 2),
                    ],
                    const SizedBox(height: OlSpace.md),
                    Row(
                      children: [
                        KPill(
                          f.lunas
                              ? 'Lunas${f.total == null ? '' : ' · ${_rp.format(f.total)}'}'
                              : (f.menunggu ? 'Jadwal belum diterima' : 'Tanpa pembayaran online'),
                          icon: f.lunas ? OlIcons.checkCircle : (f.menunggu ? OlIcons.clock : OlIcons.info),
                          tone: f.lunas ? KPillTone.ok : (f.menunggu ? KPillTone.warn : KPillTone.muted),
                        ),
                        const Spacer(),
                        Text('Masuk ${relatif(f.dikirim).toLowerCase()}', style: t.caption.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final u = umur(p?.ttl);
    return [
      KHero(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KAvatar(name: f.nama, size: 58, ring: true),
                const SizedBox(width: OlSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.nama, style: t.title.copyWith(color: Colors.white, fontSize: 20, height: 1.15)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          KPill(
                            p?.nomor == null ? 'Pasien baru' : nomorPasien(p!.nomor),
                            tone: KPillTone.glass,
                            mono: p?.nomor != null,
                          ),
                          KPill(f.dariAplikasi ? 'Aplikasi pasien' : 'Form web', tone: KPillTone.glass),
                          if (u != null) KPill('$u tahun', tone: KPillTone.glass),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: OlSpace.lg),
            Container(
              padding: const EdgeInsets.all(OlSpace.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  if (f.menunggu) const KPulseDot(color: Color(0xFFFFC56B)),
                  if (!f.menunggu) const OlIcon(OlIcons.checkCircle, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.menunggu
                          ? 'Jadwal belum diterima — otomatis diterima saat disetujui'
                          : (f.lunas ? 'Sudah terjadwal · lunas' : 'Sudah terjadwal'),
                      style: t.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      KFormSection(
        icon: OlIcons.pain,
        title: 'Keluhan',
        children: [
          KQuote(i.keluhan ?? 'Tidak diisi'),
          if (i.penyebab != null || i.lamaCedera != null || i.rontgen != null || i.catatan != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KTextBlock(icon: OlIcons.alert, label: 'Penyebab', value: i.penyebab),
                KTextBlock(icon: OlIcons.clock, label: 'Lama cedera', value: i.lamaCedera),
                KTextBlock(icon: OlIcons.xray, label: 'Rontgen', value: i.rontgen),
                KTextBlock(icon: OlIcons.chat, label: 'Catatan', value: i.catatan),
              ],
            ),
        ],
      ),
      if (f.fileRontgen > 0)
        KFormSection(
          icon: OlIcons.xray,
          title: 'Foto Rontgen / MRI',
          children: [IntakeXray.booking(bookingId: f.id)],
        ),
      KFormSection(
        icon: OlIcons.calendar,
        title: 'Jadwal & Layanan',
        children: [
          KGrid(
            items: [
              KGridItem(KInfoTile(icon: OlIcons.package, label: 'Layanan', value: f.layanan), wide: true),
              KGridItem(
                KInfoTile(
                  icon: f.homeVisit ? OlIcons.homeVisit : OlIcons.calendar,
                  label: f.homeVisit ? 'Jadwal · home visit' : 'Jadwal',
                  value: _when(f.jadwal),
                ),
                wide: true,
              ),
              KGridItem(KInfoTile(icon: OlIcons.clock, label: 'Dikirim', value: relatif(f.dikirim))),
              KGridItem(
                KInfoTile(
                  icon: OlIcons.cash,
                  label: 'Pembayaran',
                  value: f.lunas ? 'Lunas${f.total == null ? '' : ' · ${_rp.format(f.total)}'}' : 'Belum online',
                ),
              ),
            ],
          ),
        ],
      ),
      if (p != null)
        KFormSection(
          icon: OlIcons.user,
          title: 'Data Diri',
          children: [
            KGrid(
              items: [
                KGridItem(
                  KInfoTile(
                    icon: OlIcons.calendar,
                    label: 'Tanggal lahir',
                    value: [if (p.tempatLahir != null) p.tempatLahir!, tgl(p.ttl)].join(', '),
                  ),
                  wide: true,
                ),
                if (p.tlp != null)
                  KGridItem(KInfoTile(icon: OlIcons.phone, label: 'Telepon', value: p.tlp!), wide: true),
                KGridItem(KInfoTile(icon: OlIcons.pin, label: 'Alamat', value: p.alamat ?? '-'), wide: true),
                KGridItem(KInfoTile(icon: OlIcons.user, label: 'Jenis kelamin', value: genderLabel(p.gender))),
                KGridItem(KInfoTile(icon: OlIcons.branch, label: 'Instansi', value: p.instansi ?? '-')),
                KGridItem(
                  KInfoTile(
                    icon: OlIcons.body,
                    label: 'BB / TB',
                    value:
                        '${p.bb == null ? '-' : '${fmtNum(p.bb!)} kg'} · ${p.tb == null ? '-' : '${fmtNum(p.tb!)} cm'}',
                  ),
                ),
                KGridItem(KInfoTile(icon: OlIcons.exercise, label: 'Hobi', value: p.hobi ?? '-')),
              ],
            ),
          ],
        ),
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
      OlButton(label: 'Tolak', variant: OlButtonVariant.danger, onPressed: _save),
    ],
  );
}

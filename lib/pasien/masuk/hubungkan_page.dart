import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/api_error_mapper.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_session.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// PS-03 Hubungkan data lama / daftar baru. Nomor HP cocok dengan pasien lama → konfirmasi
/// tanggal lahir (maks 3 percobaan, server yang menghitung). Nama disamarkan sampai terbukti.
/// Tidak ada kecocokan (atau "Bukan saya") → daftar sebagai pasien baru.
class HubungkanPage extends ConsumerStatefulWidget {
  const HubungkanPage({super.key});

  @override
  ConsumerState<HubungkanPage> createState() => _HubungkanPageState();
}

class _HubungkanPageState extends ConsumerState<HubungkanPage> {
  LinkCandidates? _data;
  AppError? _loadError;
  bool _register = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final d = await ref.read(pasienSessionProvider.notifier).linkCandidates();
      if (!mounted) return;
      setState(() {
        _data = d;
        _register = d.candidates.isEmpty;
      });
    } on AppError catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (_loadError != null) {
      return OlMessageScreen(
        illustration: OlIllustration.serverError,
        title: 'Data belum bisa dimuat',
        message: 'Periksa koneksi internet Anda, lalu coba lagi.',
        foot: [OlButton(label: 'Coba lagi', onPressed: _load)],
      );
    }
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_register) {
      return _RegisterForm(
        canGoBack: data.candidates.isNotEmpty,
        onBack: () => setState(() => _register = false),
      );
    }
    return _LinkForm(
      data: data,
      onRegister: () => setState(() => _register = true),
    );
  }
}

class _LinkForm extends ConsumerStatefulWidget {
  const _LinkForm({required this.data, required this.onRegister});

  final LinkCandidates data;
  final VoidCallback onRegister;

  @override
  ConsumerState<_LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends ConsumerState<_LinkForm> {
  late LinkCandidate _pick = widget.data.candidates.first;
  late int _attempts = widget.data.attemptsLeft;
  late bool _locked = widget.data.locked;
  int? _day;
  int? _month;
  int? _year;
  String? _error;
  bool _busy = false;

  Future<void> _choose({
    required String title,
    required List<int> values,
    required String Function(int) label,
    required ValueChanged<int> onPick,
  }) async {
    final v = await context.feedback.formSheet<int>(
      title: title,
      builder: (ctx, close) => SizedBox(
        height: 320,
        child: ListView(
          children: [
            for (final x in values)
              OlListItem(title: label(x), onTap: () => close(x)),
          ],
        ),
      ),
    );
    if (v != null) setState(() => onPick(v));
  }

  Future<void> _link() async {
    final birth = DateTime(_year!, _month!, _day!);
    if (birth.month != _month) {
      setState(() => _error = 'Tanggal tidak valid.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(pasienSessionProvider.notifier)
          .link(patientId: _pick.id, birthDate: birth);
      if (mounted) {
        context.feedback.success('Riwayat terapi Anda sudah terhubung.');
      }
    } on AppError catch (e) {
      if (!mounted) return;
      final msg = e.fieldError('birth_date');
      setState(() {
        _busy = false;
        _error = msg;
        if (msg != null) {
          _attempts = (_attempts - 1).clamp(0, 3);
          _locked = msg.contains('Hubungi klinik');
        }
      });
      if (msg == null) context.feedback.error(e, retry: _link);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final canTry = !_locked && _attempts > 0;
    Widget box(String text, VoidCallback onTap, String label, bool focus) =>
        Expanded(
          child: Semantics(
            container: true,
            button: true,
            label: '$label: $text',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(OlRadius.input),
              onTap: canTry ? onTap : null,
              child: Container(
                height: OlSize.input,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(OlRadius.input),
                  border: Border.all(
                    color: _error != null ? c.crit : (focus ? c.brand : c.line),
                    width: focus ? 2 : 1.5,
                  ),
                ),
                child: Text(text, style: t.body.copyWith(fontSize: 16)),
              ),
            ),
          ),
        );
    final now = DateTime.now().year;
    return OlDetailScaffold(
      title: 'Kami menemukan data Anda',
      showBack: false,
      background: c.surface,
      foot: [
        OlButton(
          label: 'Hubungkan',
          loading: _busy,
          onPressed:
              canTry &&
                  _day != null &&
                  _month != null &&
                  _year != null &&
                  !_busy
              ? _link
              : null,
        ),
      ],
      children: [
        Text(
          'Nomor ini terdaftar di One Lotus. Konfirmasi tanggal lahir untuk menghubungkan riwayat terapi Anda.',
          style: t.body.copyWith(fontSize: 15, color: c.muted),
        ),
        for (final cand in widget.data.candidates)
          Semantics(
            selected: cand.id == _pick.id,
            button: widget.data.candidates.length > 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(OlRadius.card),
              onTap: widget.data.candidates.length > 1
                  ? () => setState(() => _pick = cand)
                  : null,
              child: Container(
                padding: const EdgeInsets.all(OlSpace.lg),
                decoration: BoxDecoration(
                  color: c.surfaceAlt.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(OlRadius.card),
                  border:
                      cand.id == _pick.id && widget.data.candidates.length > 1
                      ? Border.all(color: c.brand, width: 2)
                      : null,
                ),
                child: Row(
                  children: [
                    OlAvatar(name: cand.maskedName, large: true),
                    const SizedBox(width: OlSpace.lg),
                    Expanded(
                      child: Text(
                        cand.maskedName,
                        semanticsLabel: 'Nama disamarkan',
                        style: t.bodyStrong.copyWith(fontSize: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                text: 'Tanggal lahir',
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: c.crit),
                  ),
                ],
              ),
              style: t.fieldLabel,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                box(
                  '${_day ?? '–'}',
                  () => _choose(
                    title: 'Tanggal',
                    values: [for (var i = 1; i <= 31; i++) i],
                    label: (x) => '$x',
                    onPick: (v) => _day = v,
                  ),
                  'Tanggal',
                  true,
                ),
                const SizedBox(width: OlSpace.md),
                box(
                  _month == null ? '–' : _months[_month! - 1],
                  () => _choose(
                    title: 'Bulan',
                    values: [for (var i = 1; i <= 12; i++) i],
                    label: (x) => _months[x - 1],
                    onPick: (v) => _month = v,
                  ),
                  'Bulan',
                  false,
                ),
                const SizedBox(width: OlSpace.md),
                box(
                  '${_year ?? '–'}',
                  () => _choose(
                    title: 'Tahun',
                    values: [for (var i = now; i >= now - 110; i--) i],
                    label: (x) => '$x',
                    onPick: (v) => _year = v,
                  ),
                  'Tahun',
                  false,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _error ??
                  (canTry
                      ? 'Sisa $_attempts percobaan. Setelah itu, hubungi klinik untuk menghubungkan data.'
                      : 'Data belum bisa dihubungkan. Hubungi klinik untuk menghubungkan data.'),
              style: t.body.copyWith(
                fontSize: 14,
                color: _error != null || !canTry ? c.crit : c.muted,
              ),
            ),
          ],
        ),
        Divider(color: c.line, height: 1),
        Center(
          child: OlButton.text(
            label: 'Bukan saya — daftar sebagai pasien baru',
            onPressed: widget.onRegister,
          ),
        ),
      ],
    );
  }
}

/// Daftar pasien baru (isian sama dengan formulir intake / KS-04 bagian identitas).
class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm({required this.canGoBack, required this.onBack});

  final bool canGoBack;
  final VoidCallback onBack;

  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  final _address = TextEditingController();
  DateTime? _birth;
  Gender? _gender;
  bool _busy = false;
  Map<String, List<String>> _errors = const {};

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _address.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().length >= 2 && _birth != null && _gender != null;

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('id'),
      helpText: 'Tanggal lahir',
    );
    if (d != null) setState(() => _birth = d);
  }

  Future<void> _submit() async {
    final s = ref.read(pasienSessionProvider);
    setState(() {
      _busy = true;
      _errors = const {};
    });
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ref
          .read(pasienSessionProvider.notifier)
          .register(
            PatientDraft(
              name: _name.text.trim(),
              birthDate: _birth!,
              gender: _gender!,
              phone: s.account?.phone ?? s.phone,
              birthPlace: opt(_place),
              address: opt(_address),
              healthConsent: true,
            ),
          );
    } on DuplicatePatientError {
      if (!mounted) return;
      setState(() => _busy = false);
      context.feedback.info(
        'Data Anda sepertinya sudah ada di klinik. Hubungkan data lama atau hubungi klinik.',
      );
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors = e.fieldErrors;
      });
      if (e.fieldErrors.isEmpty) context.feedback.error(e, retry: _submit);
    }
  }

  String? _err(String f) => _errors[f]?.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    void touch(String _) => setState(() {});
    return OlDetailScaffold(
      title: 'Daftar pasien baru',
      showBack: false,
      background: c.surface,
      foot: [
        OlButton(
          label: 'Daftar',
          loading: _busy,
          onPressed: _valid && !_busy ? _submit : null,
        ),
      ],
      children: [
        Text(
          'Belum ada data dengan nomor ini. Lengkapi data diri Anda untuk mulai memakai aplikasi.',
          style: t.body.copyWith(fontSize: 15, color: c.muted),
        ),
        OlTextField(
          label: 'Nama lengkap',
          isRequired: true,
          controller: _name,
          error: _err('name'),
          onChanged: touch,
        ),
        Semantics(
          button: true,
          label: 'Tanggal lahir',
          child: InkWell(
            onTap: _pickBirth,
            borderRadius: BorderRadius.circular(OlRadius.input),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Tanggal lahir *',
                errorText: _err('birth_date'),
              ),
              child: Text(
                _birth == null ? 'Pilih tanggal' : Fmt.dateNoDay(_birth!),
                style: t.body.copyWith(
                  fontSize: 15,
                  color: _birth == null ? c.faint : c.fg,
                ),
              ),
            ),
          ),
        ),
        OlSegmented<Gender?>(
          segments: {for (final g in Gender.values) g: g.label},
          value: _gender,
          onChanged: (v) => setState(() => _gender = v),
        ),
        OlTextField(label: 'Tempat lahir', controller: _place),
        OlTextField(label: 'Alamat', controller: _address),
        if (widget.canGoBack)
          Center(
            child: OlButton.text(
              label: 'Kembali ke data yang ditemukan',
              onPressed: widget.onBack,
            ),
          ),
      ],
    );
  }
}

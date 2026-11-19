import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/pasien/pasien_app_api.dart';
import '../../features/kasir/billing_common.dart';
import '../../features/owner/owner_widgets.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Sumber titik lokasi alamat.
enum _PointSource { none, gps, search, saved }

/// PS-19 Tambah / ubah alamat home visit:
/// - "Gunakan lokasi saya" → GPS + alamat otomatis dari peta,
/// - ketik → saran alamat dari peta (OpenStreetMap lewat backend), pilih → alamat & titik terisi,
/// - alamat lengkap tetap bisa diedit manual (nomor rumah, RT/RW, dsb.).
/// Titik lokasi wajib: jarak & biaya transport home visit dihitung dari titik ini.
/// Hasil: alamat tersimpan, atau null bila dibatalkan.
class AlamatFormPage extends ConsumerStatefulWidget {
  const AlamatFormPage({super.key, this.initial});
  final AddressV? initial;

  @override
  ConsumerState<AlamatFormPage> createState() => _AlamatFormPageState();
}

class _AlamatFormPageState extends ConsumerState<AlamatFormPage> {
  late final _label = TextEditingController(text: widget.initial?.label ?? 'Rumah');
  late final _address = TextEditingController(text: widget.initial?.address ?? '');
  late final _landmark = TextEditingController(text: widget.initial?.landmark ?? '');
  late bool _isDefault = widget.initial?.isDefault ?? false;

  double? _lat, _lng;
  double? _accuracy;
  _PointSource _source = _PointSource.none;

  String _query = '';
  List<GeoPlaceV> _results = const [];
  bool _searching = false, _locating = false, _saving = false;
  String? _searchError, _formError;
  Timer? _debounce;
  int _searchSeq = 0;

  /// Posisi terakhir perangkat (tanpa meminta izin) — saran alamat diutamakan yang dekat.
  Position? _bias;

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    if (a != null && (a.lat != 0 || a.lng != 0)) {
      _lat = a.lat;
      _lng = a.lng;
      _source = _PointSource.saved;
    }
    _loadBias();
  }

  Future<void> _loadBias() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        _bias = await Geolocator.getLastKnownPosition();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _label.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  // ── cari alamat ──

  void _onQuery(String q) {
    _query = q.trim();
    _debounce?.cancel();
    if (_query.length < 3) {
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final seq = ++_searchSeq;
    final q = _query;
    try {
      final list = await _api.geoSearch(q, lat: _lat ?? _bias?.latitude, lng: _lng ?? _bias?.longitude);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = list;
        _searching = false;
        _searchError = null;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = 'Saran alamat belum bisa dimuat. Gunakan lokasi Anda atau ketik alamat di bawah.';
      });
    }
  }

  void _pick(GeoPlaceV p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _address.text = p.address;
      _lat = p.lat;
      _lng = p.lng;
      _accuracy = null;
      _source = _PointSource.search;
      _results = const [];
      _formError = null;
    });
    context.feedback.info('Alamat terisi. Lengkapi nomor rumah / RT-RW bila perlu.');
  }

  // ── GPS ──

  Future<void> _useMyLocation() async {
    FocusScope.of(context).unfocus();
    setState(() => _locating = true);
    try {
      final pos = await _position();
      if (pos == null || !mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _accuracy = pos.accuracy;
        _source = _PointSource.gps;
        _formError = null;
      });
      // Isi alamat dari peta; gagal → titik tetap tersimpan, alamat diketik manual.
      try {
        final p = await _api.geoReverse(pos.latitude, pos.longitude);
        if (!mounted) return;
        if (p != null && p.address.isNotEmpty) {
          setState(() => _address.text = p.address);
          context.feedback.info('Lokasi ditemukan. Periksa & lengkapi alamatnya.');
        } else {
          context.feedback.info('Titik lokasi tersimpan. Ketik alamat lengkapnya di bawah.');
        }
      } catch (_) {
        if (mounted) context.feedback.info('Titik lokasi tersimpan. Ketik alamat lengkapnya di bawah.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Posisi sekarang dengan pesan yang sesuai penyebabnya (GPS mati, izin ditolak, sinyal lemah).
  Future<Position?> _position() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return null;
        final open = await context.feedback.sheet<bool>(
          title: 'Lokasi HP mati',
          message: 'Aktifkan Lokasi/GPS di HP untuk mengisi alamat otomatis.',
          actions: const [SheetAction('Buka pengaturan lokasi', true), SheetAction('Nanti', false, variant: OlButtonVariant.text)],
        );
        if (open == true) await Geolocator.openLocationSettings();
        return null;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return null;
        final open = await context.feedback.sheet<bool>(
          title: 'Izin lokasi ditolak',
          message: 'Izinkan akses lokasi untuk One Lotus di pengaturan aplikasi, lalu coba lagi.',
          actions: const [SheetAction('Buka pengaturan aplikasi', true), SheetAction('Nanti', false, variant: OlButtonVariant.text)],
        );
        if (open == true) await Geolocator.openAppSettings();
        return null;
      }
      if (perm == LocationPermission.denied) {
        if (mounted) context.feedback.info('Izin lokasi belum diberikan. Anda tetap bisa mencari alamat secara manual.');
        return null;
      }
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
        );
      } on TimeoutException {
        // Sinyal GPS lemah (di dalam ruangan): pakai posisi terakhir yang diketahui HP bila ada.
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
        if (mounted) context.feedback.info('Sinyal GPS lemah. Coba di dekat jendela/teras, atau cari alamat secara manual.');
        return null;
      }
    } catch (e) {
      debugPrint('[lokasi] gagal: $e');
      if (mounted) context.feedback.info('Lokasi belum bisa diambil. Coba lagi atau cari alamat secara manual.');
      return null;
    }
  }

  // ── simpan ──

  Future<void> _save() async {
    final label = _label.text.trim(), address = _address.text.trim();
    if (label.isEmpty || address.isEmpty) {
      setState(() => _formError = 'Isi nama dan alamat lengkap.');
      return;
    }
    if (_lat == null || _lng == null) {
      setState(() => _formError = 'Pilih alamat dari saran atau gunakan lokasi Anda, agar jarak home visit bisa dihitung.');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    final r = await runApi(
      context,
      () => _api.saveAddress(widget.initial?.id, {
        'label': label,
        'address': address,
        'landmark': _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
        'lat': _lat,
        'lng': _lng,
        'is_default': _isDefault,
      }),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      pinnedHeader: true,
      title: widget.initial == null ? 'Tambah alamat' : 'Ubah alamat',
      foot: [OlButton(label: 'Simpan alamat', icon: OlIcons.pin, loading: _saving, onPressed: _save)],
      children: [
        // 1) GPS
        _LocateCard(
          busy: _locating,
          onTap: _locating ? null : _useMyLocation,
        ),
        // 2) Cari
        Row(
          children: [
            Expanded(child: Divider(color: c.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OlSpace.sm),
              child: Text('atau cari alamat', style: t.caption.copyWith(color: c.muted)),
            ),
            Expanded(child: Divider(color: c.line)),
          ],
        ),
        OlSearchField(hint: 'Nama jalan, perumahan, atau tempat', onChanged: _onQuery),
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: OlSpace.sm),
            child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
          )
        else if (_searchError != null)
          Text(_searchError!, style: t.caption.copyWith(color: c.warn))
        else if (_results.isNotEmpty)
          _Suggestions(results: _results, onPick: _pick)
        else if (_query.length >= 3)
          Text('Alamat tidak ditemukan. Coba kata lain atau ketik manual di bawah.', style: t.caption.copyWith(color: c.muted)),
        // 3) Titik lokasi terpilih
        _PointStatus(source: _source, lat: _lat, lng: _lng, accuracy: _accuracy),
        // 4) Detail
        const OlSectionHeader(title: 'Detail alamat'),
        OlTextField(label: 'Nama alamat', controller: _label, isRequired: true, hint: 'Rumah, Kantor, Kos…'),
        Wrap(
          spacing: OlSpace.sm,
          children: [
            for (final l in const ['Rumah', 'Kantor', 'Kos', 'Rumah orang tua'])
              OlChip(label: l, small: true, selected: _label.text == l, onTap: () => setState(() => _label.text = l)),
          ],
        ),
        OlTextField(
          label: 'Alamat lengkap',
          controller: _address,
          maxLines: 3,
          isRequired: true,
          hint: 'Jalan, nomor rumah, RT/RW, kelurahan',
        ),
        OlTextField(label: 'Patokan', controller: _landmark, hint: 'Mis. pagar hijau, sebelah masjid'),
        OwToggleRow(label: 'Jadikan alamat utama', value: _isDefault, onChanged: (v) => setState(() => _isDefault = v)),
        if (_formError != null) OlBanner(tone: OlBannerTone.crit, message: _formError!),
      ],
    );
  }
}

class _LocateCard extends StatelessWidget {
  const _LocateCard({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: busy
                ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.brand))
                : OlIcon(OlIcons.pin, color: c.brandDeep, weight: OlIconWeight.duotone),
          ),
          const SizedBox(width: OlSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(busy ? 'Mencari lokasi Anda…' : 'Gunakan lokasi saya sekarang', style: t.bodyStrong),
                Text(
                  'Paling tepat bila Anda sedang berada di alamat ini.',
                  style: t.caption.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          OlIcon(OlIcons.chevronRight, color: c.faint, size: 18),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.results, required this.onPick});
  final List<GeoPlaceV> results;
  final ValueChanged<GeoPlaceV> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, p) in results.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 52, color: c.line),
            InkWell(
              onTap: () => onPick(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: OlIcon(OlIcons.pin, size: 18, color: c.brand),
                    ),
                    const SizedBox(width: OlSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (p.subtitle.isNotEmpty)
                            Text(p.subtitle, style: t.caption.copyWith(color: c.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(OlSpace.lg, 4, OlSpace.lg, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Data peta © OpenStreetMap', style: t.caption.copyWith(color: c.faint, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointStatus extends StatelessWidget {
  const _PointStatus({required this.source, this.lat, this.lng, this.accuracy});
  final _PointSource source;
  final double? lat, lng, accuracy;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final has = lat != null && lng != null;
    final text = switch (source) {
      _PointSource.gps => 'Titik lokasi dari GPS${accuracy != null ? ' (akurasi ±${accuracy!.round()} m)' : ''}',
      _PointSource.search => 'Titik lokasi dari alamat yang dipilih',
      _PointSource.saved => 'Titik lokasi tersimpan',
      _PointSource.none => 'Belum ada titik lokasi',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: OlSpace.md, vertical: 10),
      decoration: BoxDecoration(
        color: has ? c.okSoft : c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          OlIcon(has ? OlIcons.checkCircle : OlIcons.info, size: 18, color: has ? c.ok : c.muted),
          const SizedBox(width: OlSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: t.caption.copyWith(color: has ? c.ok : c.muted, fontWeight: FontWeight.w700)),
                if (has)
                  Text(
                    '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                    style: t.mono.copyWith(fontSize: 11.5, color: c.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

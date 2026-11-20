import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Pilih titik alamat langsung di peta (PS-19): pin tetap di tengah, peta yang digeser.
/// Setiap peta berhenti bergerak, alamat jalan di titik itu dibaca dari peta (reverse geocoding).
/// Hasil: [GeoPlaceV] dengan lat/lng titik pin (alamat boleh kosong bila tidak ditemukan), atau null.
/// Peta: OpenStreetMap (tanpa API key). Halaman ini satu-satunya tempat peta interaktif — ganti di sini
/// bila nanti memakai Google Maps.
class PetaTitikPage extends ConsumerStatefulWidget {
  const PetaTitikPage({super.key, this.initial});

  /// Alamat tile peta. Bawaan: server publik OpenStreetMap — cukup untuk uji coba, tetapi kebijakannya
  /// tidak untuk aplikasi produksi bervolume (operations.osmfoundation.org/policies/tiles).
  /// Saat rilis isi `--dart-define=MAP_TILE_URL=` dengan penyedia ber-API key (MapTiler/Stadia/dll.).
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// Tes: tanpa lapisan tile (butuh jaringan & path_provider).
  @visibleForTesting
  static bool showTiles = true;

  /// Titik awal (alamat yang sedang diubah / hasil GPS / saran yang dipilih).
  final LatLng? initial;

  @override
  ConsumerState<PetaTitikPage> createState() => _PetaTitikPageState();
}

class _PetaTitikPageState extends ConsumerState<PetaTitikPage> {
  final _map = MapController();
  LatLng? _center;
  GeoPlaceV? _place;
  bool _moving = false, _reading = false, _locating = false;
  Timer? _idle;
  int _seq = 0;

  PasienAppApi get _api => ref.read(pasienAppApiProvider);

  @override
  void initState() {
    super.initState();
    _center = widget.initial;
    if (_center == null) {
      _startPoint();
    } else {
      _read(_center!);
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  /// Tanpa titik awal: posisi terakhir HP (bila izin sudah ada) → titik cabang.
  Future<void> _startPoint() async {
    LatLng? p;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) p = LatLng(last.latitude, last.longitude);
      }
    } catch (_) {}
    if (p == null) {
      try {
        final b = (await _api.branchPoints()).firstOrNull;
        if (b != null) p = LatLng(b.lat, b.lng);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _center = p ?? const LatLng(-2.5, 118)); // tengah Indonesia bila semua gagal
    if (p != null) _read(p);
  }

  void _onMoved(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (!_moving) setState(() => _moving = true);
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      setState(() => _moving = false);
      HapticFeedback.selectionClick();
      _read(camera.center);
    });
  }

  Future<void> _read(LatLng p) async {
    final seq = ++_seq;
    setState(() => _reading = true);
    try {
      final place = await _api.geoReverse(p.latitude, p.longitude);
      if (!mounted || seq != _seq) return;
      setState(() {
        _place = place;
        _reading = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _place = null;
        _reading = false;
      });
    }
  }

  Future<void> _myLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) context.feedback.info('Izin lokasi belum diberikan. Geser peta ke rumah Anda secara manual.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      final p = LatLng(pos.latitude, pos.longitude);
      _map.move(p, 18);
      _center = p;
      await _read(p);
    } catch (_) {
      if (mounted) context.feedback.info('Lokasi belum didapat. Geser peta ke rumah Anda secara manual.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    final c = _center;
    if (c == null) return;
    final p = _place;
    Navigator.of(context).pop(
      GeoPlaceV(
        title: p?.title ?? '',
        subtitle: p?.subtitle ?? '',
        address: p?.address ?? '',
        lat: c.latitude,
        lng: c.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final center = _center;
    return Scaffold(
      backgroundColor: c.bg,
      body: center == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: widget.initial != null ? 18 : 16,
                    minZoom: 5,
                    maxZoom: 19,
                    onPositionChanged: _onMoved,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    if (PetaTitikPage.showTiles)
                      TileLayer(
                        urlTemplate: PetaTitikPage.tileUrl,
                        userAgentPackageName: 'com.onelotus.onelotus_staff',
                        maxZoom: 19,
                      ),
                  ],
                ),
                // Pin tetap di tengah; terangkat saat peta digeser.
                IgnorePointer(
                  child: Center(
                    child: AnimatedSlide(
                      duration: OlMotion.of(context, OlMotion.fast),
                      offset: Offset(0, _moving ? -.62 : -.5),
                      child: _Pin(color: c.brandDeep, lifted: _moving),
                    ),
                  ),
                ),
                // Bar atas: kembali + petunjuk.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(OlSpace.md),
                    child: Row(
                      children: [
                        Material(
                          color: c.surface,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: OlBackButton(onPressed: () => Navigator.of(context).pop()),
                        ),
                        const SizedBox(width: OlSpace.sm),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: OlShadow.sh1,
                            ),
                            child: Text(
                              'Geser peta sampai pin tepat di rumah Anda',
                              style: t.caption.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Atribusi wajib OpenStreetMap (di atas kartu bawah agar tidak tertutup).
                Positioned(
                  left: OlSpace.md,
                  bottom: 214,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.white.withValues(alpha: .8),
                    child: Text('© OpenStreetMap', style: t.caption.copyWith(fontSize: 10.5, color: c.muted)),
                  ),
                ),
                // Tombol lokasi saya.
                Positioned(
                  right: OlSpace.md,
                  bottom: 210,
                  child: Material(
                    color: c.surface,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _locating ? null : _myLocation,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: _locating
                              ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.brand))
                              : Icon(Icons.my_location_rounded, color: c.brandDeep),
                        ),
                      ),
                    ),
                  ),
                ),
                // Kartu alamat di titik pin + konfirmasi.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      OlSpace.lg,
                      OlSpace.lg,
                      OlSpace.lg,
                      OlSpace.lg + MediaQuery.paddingOf(context).bottom,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: OlShadow.sh1,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OlIcon(OlIcons.pin, color: c.brandDeep, weight: OlIconWeight.duotone),
                            const SizedBox(width: OlSpace.sm),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: OlMotion.of(context, OlMotion.fast),
                                child: _moving || _reading
                                    ? Column(
                                        key: const ValueKey('busy'),
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Membaca alamat…', style: t.bodyStrong.copyWith(color: c.muted)),
                                          const SizedBox(height: 6),
                                          const Skeleton(height: 12),
                                        ],
                                      )
                                    : Column(
                                        key: ValueKey(_place?.address ?? 'none'),
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _place?.title.isNotEmpty == true ? _place!.title : 'Titik dipilih',
                                            style: t.bodyStrong,
                                          ),
                                          Text(
                                            _place?.subtitle.isNotEmpty == true
                                                ? _place!.subtitle
                                                : 'Alamat jalan tidak terbaca — Anda bisa mengetiknya setelah ini.',
                                            style: t.caption.copyWith(color: c.muted),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: OlSpace.md),
                        OlButton(label: 'Pakai titik ini', onPressed: _moving ? null : _confirm),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Pin peta: kepala bulat + jarum; bayangan di titik tepat.
class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.lifted});
  final Color color;
  final bool lifted;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: const Center(child: CircleAvatar(radius: 4, backgroundColor: Colors.white)),
      ),
      Container(width: 3, height: 16, color: color),
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: lifted ? 6 : 10,
        height: lifted ? 3 : 4,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: lifted ? .15 : .3),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ],
  );
}

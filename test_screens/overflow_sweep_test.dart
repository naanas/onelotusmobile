// Penyapu overflow: buka semua layar di beberapa lebar HP & ukuran huruf,
// kumpulkan setiap "RenderFlex overflowed" beserta rutenya, lalu gagal bila ada.
// Tinggi layar dibuat sangat besar agar seluruh isi ListView ikut ditata.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/app.dart';
import 'package:onelotus_staff/data/auth/auth_controller.dart';
import 'package:onelotus_staff/data/models/staff_user.dart';
import 'package:onelotus_staff/pasien/pasien_session.dart';
import 'package:onelotus_staff/router/app_router.dart';

import '../test/auth/fakes.dart';
import 'app_helpers.dart';

typedef _Cfg = ({double width, double scale});

const _configs = <_Cfg>[
  (width: 360, scale: 1.0),
  (width: 360, scale: 1.3),
  (width: 412, scale: 1.0),
  (width: 412, scale: 1.3),
];

const _terapis = [
  '/terapis/jadwal',
  '/terapis/pasien',
  '/terapis/riwayat',
  '/terapis/akun',
  '/terapis/jadwal-minggu',
  '/terapis/cuti',
  '/terapis/pasien/p0387',
  '/terapis/sesi/s1',
  '/terapis/home-visit/s4',
  '/terapis/home-visit/s4/tagih',
  '/terapis/kas',
  '/terapis/komisi',
  '/terapis/pasien/p0387/latihan',
  '/terapis/pilih-pasien',
  '/terapis/rekam/s2',
  '/perbarui',
  '/pemeliharaan',
  '/notifikasi',
  '/cari',
  '/ubah-password',
  '/pengaturan-notifikasi',
  '/status-sinkron',
  '/bantuan',
];

const _kasir = [
  '/kasir/antrian',
  '/kasir/pasien',
  '/kasir/kasir',
  '/kasir/akun',
  '/kasir/intake',
  '/kasir/pasien-form',
  '/kasir/pasien/p0412',
  '/kasir/buat-jadwal',
  '/kasir/booking',
  '/kasir/pindah-massal',
  '/kasir/bayar',
  '/kasir/struk',
  '/kasir/jual-paket',
  '/kasir/riwayat',
  '/kasir/refund',
  '/kasir/verifikasi-transfer',
  '/kasir/terima-kas',
  '/kasir/tutup-kas',
  '/kasir/piutang',
];

const _owner = [
  '/owner/ringkasan',
  '/owner/jadwal',
  '/owner/pasien',
  '/owner/laporan',
  '/owner/akun',
  '/owner/ekspor',
  '/owner/persetujuan',
  '/owner/komisi',
  '/owner/staf',
  '/owner/layanan',
  '/owner/paket',
  '/owner/aturan-komisi',
  '/owner/voucher',
  '/owner/poin',
  '/owner/template',
  '/owner/pustaka',
  '/owner/pengumuman',
  '/owner/cabang',
  '/owner/audit',
  '/owner/rekonsiliasi',
  '/owner/pengingat',
];

const _pasien = [
  '/pasien/beranda',
  '/pasien/latihan',
  '/pasien/booking',
  '/pasien/profil',
  '/pasien/latihan/calf-raise',
  '/pasien/bayar',
  '/pasien/jadwal',
  '/pasien/jadwal/ubah',
  '/pasien/riwayat',
  '/pasien/paket',
  '/pasien/paket/beli',
  '/pasien/struk',
  '/pasien/poin',
  '/pasien/notifikasi',
  '/pasien/alamat',
  '/pasien/hapus-akun',
  '/pasien/persetujuan-data',
];

void _view(WidgetTester t, _Cfg cfg) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(cfg.width, 4000);
  t.view.padding = const FakeViewPadding(top: 24, bottom: 16);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
  t.platformDispatcher.textScaleFactorTestValue = cfg.scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _open(
  WidgetTester t, {
  (String, String, Role)? staff,
  bool pasien = false,
}) async {
  final h = AuthHarness()..device.available = false;
  h.clock.now = DateTime(2026, 10, 6, 10, 42);
  final c = h.container();
  if (staff != null) {
    final (u, p, role) = staff;
    await t.runAsync(() async {
      final a = c.read(authProvider.notifier);
      await a.login(u, p, remember: false);
      await a.setPin('123456');
      await a.completeFirstLogin();
      if (c.read(authProvider).phase == AuthPhase.chooseContext) {
        await a.chooseContext(role, c.read(authProvider).user!.branches.first);
      }
    });
  }
  if (pasien) c.read(pasienSessionProvider.notifier).skipToReady();
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(container: c, child: const OneLotusApp()),
  );
  await pumpFor(t, const Duration(seconds: 2));
}

/// Kumpulkan overflow (dengan rute & file:baris penyebab) selama [body] berjalan.
Future<List<String>> _collect(
  Future<void> Function(void Function(String) at) body,
) async {
  final found = <String>[];
  var current = 'buka aplikasi';
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final msg = d.exceptionAsString();
    if (!msg.contains('overflowed')) return original?.call(d);
    final text = d.toString();
    final where = RegExp(
      r'lib/[\w/]+\.dart:\d+',
    ).allMatches(text).map((m) => m.group(0)).firstOrNull;
    final creator = RegExp(
      r'creator: ([^\n]+(?:\n[^\n]+){0,2})',
    ).firstMatch(text)?.group(1)?.replaceAll(RegExp(r'\s+'), ' ');
    found.add('$current → ${msg.split('\n').first} [${where ?? creator}]');
  };
  try {
    await body((r) => current = r);
  } finally {
    FlutterError.onError = original;
  }
  return found;
}

Future<void> _visit(
  WidgetTester t,
  List<String> routes,
  void Function(String) at,
) async {
  for (final r in routes) {
    at(r);
    rootNavigatorKey.currentContext!.go(r);
    await pumpFor(t, const Duration(milliseconds: 600));
  }
  // Tunggu transisi terakhir, lalu lepas aplikasi sebelum layar test dikembalikan.
  await pumpFor(t, const Duration(seconds: 1));
  at('lepas aplikasi');
  await t.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await loadFonts();
  });

  for (final cfg in _configs) {
    final tag = '${cfg.width.toInt()}dp × huruf ${cfg.scale}';
    for (final (name, routes, staff, pasien) in [
      (
        'terapis',
        _terapis,
        ('dimas.terapis', 'terapis123', Role.terapis),
        false,
      ),
      ('kasir', _kasir, ('sinta.kasir', 'kasir123', Role.kasir), false),
      ('owner', _owner, ('rudi.owner', 'owner123', Role.owner), false),
      ('pasien', _pasien, null, true),
    ]) {
      testWidgets('$name · $tag', (t) async {
        _view(t, cfg);
        const only = String.fromEnvironment('SWEEP_ONLY');
        final found = await _collect((at) async {
          await _open(t, staff: staff, pasien: pasien);
          await _visit(t, [
            for (final r in routes)
              if (only.isEmpty || r == only) r,
          ], at);
        });
        const out = String.fromEnvironment('SWEEP_OUT');
        if (out.isNotEmpty && found.isNotEmpty) {
          File(out).writeAsStringSync(
            '${found.map((f) => '$tag | $f').join('\n')}\n',
            mode: FileMode.append,
          );
        }
        expect(found, isEmpty, reason: found.toSet().join('\n'));
      });
    }
  }
}

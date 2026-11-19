import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pasien/pasien_app_api.dart';
import '../../router/app_router.dart';
import '../pasien_routes.dart';

/// Kanal Android untuk semua notifikasi One Lotus (id sama dengan meta-data di AndroidManifest).
const _channel = AndroidNotificationChannel(
  'onelotus_default',
  'Notifikasi One Lotus',
  description: 'Kabar booking, jadwal, pembayaran, paket, dan latihan',
  importance: Importance.high,
);

/// Push FCM aplikasi pasien.
/// - Pasien masuk → minta izin notifikasi, kirim token ke server (`POST /v1/me/devices`), pantau pergantian token.
/// - Aplikasi terbuka → push ditampilkan lewat notifikasi lokal + badge lonceng diperbarui.
/// - Aplikasi tertutup/latar → sistem menampilkan push dari FCM; diketuk → layar sesuai `data.deep_link`.
/// - Pasien keluar → token dihapus dari perangkat.
class PasienPush {
  PasienPush(this._ref);
  final Ref _ref;

  /// True bila [initFirebase] berhasil (Android dengan google-services.json). Tes & iOS tanpa konfigurasi → false.
  static bool firebaseReady = false;

  static Future<void> initFirebase() async {
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
      debugPrint('[push] Firebase siap');
    } catch (e) {
      debugPrint('[push] Firebase tidak aktif: $e');
    }
  }

  final _local = FlutterLocalNotificationsPlugin();
  final _subs = <StreamSubscription<Object?>>[];
  bool _started = false, _localReady = false;

  Future<void> start() async {
    if (!firebaseReady) debugPrint('[push] dilewati: Firebase belum siap (jalankan ulang dengan flutter run, bukan hot restart)');
    if (_started || !firebaseReady) return;
    _started = true;
    try {
      final m = FirebaseMessaging.instance;
      await _setupLocal();
      final perm = await m.requestPermission();
      debugPrint('[push] izin notifikasi: ${perm.authorizationStatus.name}');
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      // Token FCM klasik (target `token` di FCM HTTP v1, yang dipakai backend). API baru `register()` memberi
      // Firebase Installation ID dengan cara kirim berbeda — pindah bila backend ikut diubah.
      // ignore: deprecated_member_use
      final token = await m.getToken();
      if (token != null) await _register(token);
      _subs
        // ignore: deprecated_member_use
        ..add(m.onTokenRefresh.listen(_register))
        ..add(FirebaseMessaging.onMessage.listen(_onForeground))
        ..add(
          FirebaseMessaging.onMessageOpenedApp.listen(
            (msg) => _open(msg.data['deep_link'] as String?),
          ),
        );
      // Aplikasi dibuka dari push saat benar-benar tertutup.
      final initial = await m.getInitialMessage();
      if (initial != null) _open(initial.data['deep_link'] as String?);
    } catch (e) {
      debugPrint('[push] belum aktif: $e');
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    try {
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _setupLocal() async {
    if (_localReady) return;
    _localReady = true;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) => _open(r.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _register(String token) async {
    try {
      await _ref
          .read(pasienAppApiProvider)
          .registerDevice(token, platform: Platform.isIOS ? 'ios' : 'android');
      debugPrint('[push] token terdaftar di server (…${token.substring(token.length - 8)})');
    } catch (e) {
      debugPrint('[push] token gagal dikirim ke server: $e');
    }
  }

  void _onForeground(RemoteMessage msg) {
    _ref.invalidate(pasienUnreadProvider);
    final n = msg.notification;
    if (n == null) return;
    _local
        .show(
          id: msg.messageId.hashCode,
          title: n.title,
          body: n.body,
          payload: msg.data['deep_link'] as String?,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(n.body ?? ''),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        )
        .ignore();
  }

  void _open(String? link) {
    _ref.invalidate(pasienUnreadProvider);
    // Tunggu frame berikutnya: router & layar pasien sudah terpasang.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => openPasienLink(_ref.read(routerProvider), link),
    );
  }
}

final pasienPushProvider = Provider<PasienPush>((ref) {
  final push = PasienPush(ref);
  ref.onDispose(push.stop);
  return push;
});

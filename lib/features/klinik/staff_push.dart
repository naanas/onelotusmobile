import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pasien/push/pasien_push.dart' show PasienPush;
import '../../router/app_router.dart';
import 'klinik_api.dart';
import 'notifikasi.dart';

const _channel = AndroidNotificationChannel(
  'onelotus_default',
  'Notifikasi One Lotus',
  description: 'Kabar booking, jadwal, pembayaran, paket, dan latihan',
  importance: Importance.high,
);

/// Push FCM untuk admin & terapis ("pasien baru booking").
/// - Staf masuk → minta izin notifikasi, kirim token ke server (`POST /v1/me/devices`), pantau pergantian token.
/// - Aplikasi terbuka → push tampil lewat notifikasi lokal, badge lonceng & cache Formulir diperbarui.
/// - Aplikasi tertutup/latar → sistem menampilkan push; diketuk → kiriman di Formulir (`data.deep_link`).
/// - Staf keluar → token dihapus dari perangkat.
class StaffPush {
  StaffPush(this._ref);
  final Ref _ref;

  final _local = FlutterLocalNotificationsPlugin();
  final _subs = <StreamSubscription<Object?>>[];
  bool _started = false;

  Future<void> start() async {
    if (_started || !PasienPush.firebaseReady) return;
    _started = true;
    try {
      final m = FirebaseMessaging.instance;
      await _setupLocal();
      final perm = await m.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      // ignore: deprecated_member_use
      final token = await m.getToken();
      if (token != null) await _register(token);
      _subs
        // ignore: deprecated_member_use
        ..add(m.onTokenRefresh.listen(_register))
        ..add(FirebaseMessaging.onMessage.listen(_onForeground))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen((msg) => _open(msg.data['deep_link'] as String?)));
      final initial = await m.getInitialMessage();
      if (initial != null) _open(initial.data['deep_link'] as String?);
    } catch (e) {
      debugPrint('[push staf] belum aktif: $e');
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
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) => _open(r.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _register(String token) async {
    try {
      await _ref.read(klinikApiProvider).daftarPerangkat(token, platform: Platform.isIOS ? 'ios' : 'android');
    } catch (e) {
      debugPrint('[push staf] token gagal dikirim ke server: $e');
    }
  }

  /// Ada kabar baru → badge lonceng & daftar Formulir/Data Pasien dimuat ulang saat dibuka.
  void _fresh() {
    _ref.invalidate(staffUnreadProvider);
    _ref.read(klinikApiProvider).cache.expire();
  }

  void _onForeground(RemoteMessage msg) {
    _fresh();
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
    _fresh();
    final route = staffRouteForLink(link);
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ref.read(routerProvider).push(route));
  }
}

final staffPushProvider = Provider<StaffPush>((ref) {
  final push = StaffPush(ref);
  ref.onDispose(push.stop);
  return push;
});

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Inspector request/response HTTP di dalam aplikasi (seperti Chucker). Hanya aktif bila
/// `HTTP_LOG=true` di file env (`--dart-define-from-file`); log disimpan di memori HP saja.
/// Matikan untuk build yang dibagikan ke pasien: isi log memuat data pasien.
abstract final class HttpLog {
  static const enabled = bool.fromEnvironment('HTTP_LOG');

  static final talker = TalkerFlutter.init(
    settings: TalkerSettings(enabled: enabled, maxHistoryItems: 300),
  );

  static void attach(Dio dio) {
    if (!enabled) return;
    dio.interceptors.add(
      TalkerDioLogger(
        talker: talker,
        settings: TalkerDioLoggerSettings(
          printRequestHeaders: true,
          printResponseTime: true,
          hiddenHeaders: const {'authorization'},
          // Isi request masuk/daftar memuat password: tidak dicatat (respons tetap tercatat).
          requestFilter: (o) => !o.path.startsWith('/v1/auth/'),
        ),
      ),
    );
  }
}

/// Tombol mengambang "HTTP" untuk membuka daftar log; bisa digeser agar tidak menutupi tombol layar.
class HttpLogButton extends StatefulWidget {
  const HttpLogButton({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<HttpLogButton> createState() => _HttpLogButtonState();
}

class _HttpLogButtonState extends State<HttpLogButton> {
  Offset? _pos;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pos = _pos ?? Offset(size.width - 64, size.height * .55);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() {
          final p = pos + d.delta;
          _pos = Offset(p.dx.clamp(0, size.width - 52), p.dy.clamp(0, size.height - 52));
        }),
        child: Material(
          color: const Color(0xCC111827),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => widget.navigatorKey.currentState?.push(
              MaterialPageRoute<void>(builder: (_) => TalkerScreen(talker: HttpLog.talker, appBarTitle: 'Log HTTP')),
            ),
            child: const SizedBox.square(
              dimension: 52,
              child: Center(
                child: Text('HTTP', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

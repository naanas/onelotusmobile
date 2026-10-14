import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/local/local_db.dart';
import 'data/providers.dart';
import 'theme/app_theme.dart';
import 'ui/body_map/body_map_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.configured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await initializeDateFormatting('id_ID');
  final db = await LocalDb.open();
  // Pramuat peta tubuh (TR-04) agar siluet langsung tampil saat rekam sesi dibuka.
  unawaited(BodyMapData.load());
  runApp(
    ProviderScope(
      overrides: [localDbProvider.overrideWithValue(db)],
      child: const OneLotusApp(),
    ),
  );
}

/// Build tanpa `API_URL` (`--dart-define-from-file=env/dev.json`): aplikasi tidak punya server untuk dihubungi.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildOlTheme(),
    home: Builder(
      builder: (context) {
        final t = context.olText;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alamat server belum diatur', style: t.title),
                  const SizedBox(height: 12),
                  Text(
                    'Isi alamat One Lotus API di env/dev.json, lalu jalankan:',
                    style: t.body,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'flutter run --dart-define-from-file=env/dev.json',
                    style: t.mono,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

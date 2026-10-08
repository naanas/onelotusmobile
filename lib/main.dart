import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/local/local_db.dart';
import 'data/providers.dart';
import 'ui/body_map/body_map_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

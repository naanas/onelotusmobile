import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pasien/pasien_app.dart';

/// Entrypoint aplikasi pasien: `flutter run -t lib/main_pasien.dart`.
/// Slicing UI: data contoh di memori, belum memakai API pasien.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(const ProviderScope(child: PasienApp()));
}

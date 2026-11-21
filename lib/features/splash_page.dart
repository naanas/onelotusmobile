import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../ui/ui.dart';

/// Tampil sebentar saat sesi tersimpan dibaca.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.ol.brand,
    body: const Center(child: OlLogoMark(size: 64, color: Colors.white)),
  );
}

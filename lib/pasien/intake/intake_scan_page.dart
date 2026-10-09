import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/intake/intake_form_repository.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Pindai QR intake di meja front desk (KS-02) dari dalam aplikasi → formulir pasien baru.
class IntakeScanPage extends StatefulWidget {
  const IntakeScanPage({super.key});

  @override
  State<IntakeScanPage> createState() => _IntakeScanPageState();
}

class _IntakeScanPageState extends State<IntakeScanPage> {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  String? _hint;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final code = intakeCodeFromQr(b.rawValue ?? '');
      if (code != null) {
        _done = true;
        context.pushReplacement(Routes.intakeForm(code));
        return;
      }
    }
    setState(
      () => _hint =
          'Ini bukan QR formulir One Lotus. Pindai QR di meja front desk.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
            errorBuilder: (context, error) => ColoredBox(
              color: c.bg,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Izinkan akses kamera di pengaturan HP untuk memindai QR.'
                        : 'Kamera belum bisa dibuka. Minta bantuan front desk.',
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: c.muted),
                  ),
                ),
              ),
            ),
          ),
          // Bingkai bidik.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.filled(
                      tooltip: 'Tutup',
                      onPressed: () => context.pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      icon: const OlIcon(OlIcons.close, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text('Pindai QR di meja front desk', style: t.heading),
                        const SizedBox(height: 6),
                        Text(
                          _hint ??
                              'Formulir pasien baru terbuka otomatis setelah QR terbaca.',
                          textAlign: TextAlign.center,
                          style: t.body.copyWith(
                            color: _hint == null ? c.muted : c.crit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

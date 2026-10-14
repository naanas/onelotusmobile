import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// OW-18 Audit log (baca-saja): siapa melakukan apa, kapan, dari perangkat apa.
class AuditPage extends StatelessWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context) => const OlUnavailablePage(
    title: 'Audit log',
    feature: 'Tampilan audit log',
    waitingFor:
        'endpoint baca audit log (data perubahan sudah tercatat di server)',
  );
}

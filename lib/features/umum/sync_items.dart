import '../../core/format.dart';
import '../../data/remote/remote.dart';
import '../../data/sync/outbox.dart';

/// Judul & keterangan item outbox untuk UM-14 / ST-07.
String outboxTitle(OutboxItem i) => switch (i.kind) {
  OutboxKinds.sessionRecordUpsert => 'Rekam sesi',
  OutboxKinds.sessionStatus =>
    'Status sesi · ${_statusLabel(i.payload['status'])}',
  OutboxKinds.rescheduleRequest => 'Permintaan pindah jadwal',
  _ => i.kind,
};

String outboxMeta(OutboxItem i) {
  final parts = <String>[
    'Dibuat ${Fmt.dayShort(i.createdAt)} ${Fmt.time(i.createdAt)}',
    if (i.attempts > 0) '${i.attempts}× dicoba',
  ];
  return parts.join(' · ');
}

String _statusLabel(Object? s) => switch (s) {
  'arrived' => 'Hadir',
  'running' => 'Mulai',
  'done' => 'Selesai',
  'no_show' => 'Tidak datang',
  _ => '$s',
};

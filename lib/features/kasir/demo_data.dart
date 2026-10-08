// Data contoh untuk slicing UI modul Kasir — diambil dari mockup (design/screens/KS-*.png).
// Hanya ilustrasi (CLAUDE.md); nanti diganti data dari repository.

enum QueueState { scheduled, arrived, running, unpaid, paid }

/// Kartu antrian KS-01.
class DemoQueueItem {
  DemoQueueItem({
    required this.id,
    required this.time,
    required this.name,
    required this.service,
    required this.therapist,
    required this.state,
    this.room,
    this.arrivedAt,
    this.newPatient = false,
    this.dataIncomplete = false,
    this.finishedAt,
  });

  final String id;
  final String time;
  final String name;
  final String service;
  String therapist;
  QueueState state;
  String? room;
  String? arrivedAt;
  final bool newPatient;
  bool dataIncomplete;
  final String? finishedAt;
}

List<DemoQueueItem> demoQueue() => [
  DemoQueueItem(
    id: 's2',
    time: '10.30',
    name: 'Andi Pratama',
    service: 'Adjustment Therapy',
    therapist: 'Dimas',
    room: 'ruang 2',
    state: QueueState.running,
  ),
  DemoQueueItem(
    id: 's3',
    time: '11.00',
    name: 'Dewi Lestari',
    service: 'Masase cedera',
    therapist: 'Laras',
    room: 'ruang 1',
    state: QueueState.arrived,
    arrivedAt: '10.52',
  ),
  DemoQueueItem(
    id: 's5',
    time: '15.00',
    name: 'Sari Wulandari',
    service: 'Intake via QR',
    therapist: 'Dimas',
    state: QueueState.scheduled,
    newPatient: true,
    dataIncomplete: true,
  ),
  DemoQueueItem(
    id: 's1',
    time: '09.00',
    name: 'Rina Setiawati',
    service: 'Masase cedera ringan',
    therapist: 'Dimas',
    state: QueueState.unpaid,
    finishedAt: '09.48',
  ),
  DemoQueueItem(
    id: 's7',
    time: '14.00',
    name: 'Hendra Santoso',
    service: 'Masase cedera',
    therapist: 'Fajar',
    room: 'ruang 3',
    state: QueueState.scheduled,
  ),
];

/// Baris daftar pasien KS-03.
class DemoKasirPatient {
  const DemoKasirPatient(
    this.id,
    this.name,
    this.number,
    this.last, {
    this.tag,
    this.tagKind,
    this.unpaid = false,
    this.package = 0,
    this.away = false,
    this.isNew = false,
  });

  final String id;
  final String name;
  final String number;
  final String last;
  final String? tag;

  /// 'brand' | 'warn' | 'outline'
  final String? tagKind;
  final bool unpaid;
  final int package;
  final bool away;
  final bool isNew;
}

const demoKasirPatients = [
  DemoKasirPatient(
    'p0387',
    'Rina Setiawati',
    '#0387',
    'terakhir 6 Okt',
    tag: 'Paket · 1',
    tagKind: 'brand',
    package: 1,
  ),
  DemoKasirPatient(
    'p0412',
    'Andi Pratama',
    '#0412',
    'hari ini',
    tag: 'Belum lunas',
    tagKind: 'warn',
    unpaid: true,
  ),
  DemoKasirPatient(
    'p0201',
    'Budi Hartono',
    '#0358',
    '5 Okt',
    tag: 'Member',
    tagKind: 'brand',
  ),
  DemoKasirPatient('p0398', 'Dewi Lestari', '#0402', 'hari ini'),
  DemoKasirPatient(
    'p0413',
    'Sari Wulandari',
    '#0413',
    'pasien baru',
    tag: 'Baru',
    tagKind: 'outline',
    isNew: true,
  ),
  DemoKasirPatient(
    'p0399',
    'Yoga Saputra',
    '#0399',
    '5 Okt',
    tag: 'Paket · 3',
    tagKind: 'brand',
    package: 3,
  ),
  DemoKasirPatient(
    'p0276',
    'Nur Wahyuni',
    '#0276',
    '11 Agu',
    tag: 'Belum lunas',
    tagKind: 'warn',
    unpaid: true,
    away: true,
  ),
  DemoKasirPatient('p0301', 'Lestari Kusuma', '#0301', '18 Agu', away: true),
];

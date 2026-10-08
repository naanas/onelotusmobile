// Data contoh untuk slicing UI modul Terapis — diambil dari mockup (design/screens/TR-*.png).
// Hanya ilustrasi (CLAUDE.md); nanti diganti data dari repository.

/// Baris daftar "Pasien saya" (TR-06).
class DemoPatientRow {
  const DemoPatientRow({
    required this.id,
    required this.initials,
    required this.name,
    required this.number,
    required this.area,
    required this.lastVisit,
    this.packageLeft,
    this.homeVisit = false,
    this.daysAway,
    this.activeThisMonth = false,
  });

  final String id;
  final String initials;
  final String name;
  final String number;
  final String area;
  final String lastVisit;
  final int? packageLeft;
  final bool homeVisit;

  /// Belum kembali n hari (tampil bila > 30).
  final int? daysAway;
  final bool activeThisMonth;
}

const demoMyPatients = [
  DemoPatientRow(
    id: 'p0387',
    initials: 'RS',
    name: 'Rina Setiawati',
    number: '#0387',
    area: 'Ankle kiri',
    lastVisit: '6 Okt',
    packageLeft: 1,
    activeThisMonth: true,
  ),
  DemoPatientRow(
    id: 'p0412',
    initials: 'AP',
    name: 'Andi Pratama',
    number: '#0412',
    area: 'LBP',
    lastVisit: 'hari ini',
    activeThisMonth: true,
  ),
  DemoPatientRow(
    id: 'p0201',
    initials: 'BH',
    name: 'Budi Hartono',
    number: '#0358',
    area: 'LBP kronis',
    lastVisit: '29 Sep',
    homeVisit: true,
  ),
  DemoPatientRow(
    id: 'p0301',
    initials: 'LK',
    name: 'Lestari Kusuma',
    number: '#0301',
    area: 'Bahu kiri',
    lastVisit: '18 Agu',
    daysAway: 49,
  ),
  DemoPatientRow(
    id: 'p0399',
    initials: 'YS',
    name: 'Yoga Saputra',
    number: '#0399',
    area: 'Hamstring',
    lastVisit: '2 Okt',
    activeThisMonth: true,
  ),
  DemoPatientRow(
    id: 'p0276',
    initials: 'NW',
    name: 'Nur Wahyuni',
    number: '#0276',
    area: 'Leher',
    lastVisit: '11 Agu',
    daysAway: 56,
  ),
  DemoPatientRow(
    id: 'p0322',
    initials: 'HS',
    name: 'Hendra Santoso',
    number: '#0322',
    area: 'Lutut kanan',
    lastVisit: '1 Sep',
    daysAway: 36,
  ),
  DemoPatientRow(
    id: 'p0390',
    initials: 'MA',
    name: 'Maya Anggraini',
    number: '#0390',
    area: 'Punggung atas',
    lastVisit: '4 Okt',
    packageLeft: 1,
    activeThisMonth: true,
  ),
];

enum DemoHistoryTag { unsynced, paid, incomplete, noShow }

/// Baris riwayat sesi (TR-07).
class DemoHistoryRow {
  const DemoHistoryRow({
    required this.sessionId,
    required this.time,
    required this.name,
    required this.caption,
    required this.tag,
    this.homeVisit = false,
  });

  final String sessionId;
  final String time;
  final String name;
  final String caption;
  final DemoHistoryTag tag;
  final bool homeVisit;
}

const demoHistory = <(String, List<DemoHistoryRow>)>[
  (
    'Hari ini · Sel, 6 Okt',
    [
      DemoHistoryRow(
        sessionId: 's2',
        time: '10.30',
        name: 'Andi Pratama',
        caption: 'Adjustment · nyeri 7→3',
        tag: DemoHistoryTag.unsynced,
      ),
      DemoHistoryRow(
        sessionId: 's1',
        time: '09.00',
        name: 'Rina Setiawati',
        caption: 'Masase cedera · nyeri 3→2',
        tag: DemoHistoryTag.paid,
      ),
    ],
  ),
  (
    'Senin, 5 Okt',
    [
      DemoHistoryRow(
        sessionId: 'h3',
        time: '16.00',
        name: 'Yoga Saputra',
        caption: 'Stretching · catatan kosong',
        tag: DemoHistoryTag.incomplete,
      ),
      DemoHistoryRow(
        sessionId: 'h4',
        time: '13.00',
        name: 'Budi Hartono',
        caption: 'Home visit · Relaksasi Premium',
        tag: DemoHistoryTag.paid,
        homeVisit: true,
      ),
      DemoHistoryRow(
        sessionId: 'h5',
        time: '10.00',
        name: 'Dewi Lestari',
        caption: 'Adjustment · nyeri 6→4',
        tag: DemoHistoryTag.paid,
      ),
    ],
  ),
  (
    'Sabtu, 3 Okt',
    [
      DemoHistoryRow(
        sessionId: 'h6',
        time: '11.00',
        name: 'Ilham Ramadhan',
        caption: 'Masase cedera · tidak datang',
        tag: DemoHistoryTag.noShow,
      ),
    ],
  ),
  (
    'Jumat, 2 Okt',
    [
      DemoHistoryRow(
        sessionId: 'h7',
        time: '15.00',
        name: 'Yoga Saputra',
        caption: 'Stretching · nyeri 5→3',
        tag: DemoHistoryTag.paid,
      ),
      DemoHistoryRow(
        sessionId: 'h8',
        time: '09.30',
        name: 'Maya Anggraini',
        caption: 'Masase cedera · nyeri 4→2',
        tag: DemoHistoryTag.paid,
      ),
    ],
  ),
];

/// Ringkasan sesi di riwayat pasien (TR-05).
class DemoPatientSession {
  const DemoPatientSession({
    required this.sessionId,
    required this.date,
    required this.title,
    required this.caption,
  });
  final String sessionId;
  final String date;
  final String title;
  final String caption;
}

class DemoPatientDetail {
  const DemoPatientDetail({
    required this.id,
    required this.name,
    required this.number,
    required this.age,
    required this.gender,
    required this.activity,
    required this.height,
    required this.weight,
    required this.injury,
    required this.pain,
    required this.painFrom,
    required this.painTo,
    required this.sessions,
    required this.moreSessions,
    required this.legacy,
    required this.maskedPhone,
    this.packageName,
    this.packageLeft,
    this.exerciseProgram,
    this.exerciseCompliance,
    this.medicalAlert,
  });

  final String id;
  final String name;
  final String number;
  final int age;
  final String gender;
  final String activity;
  final int height;
  final int weight;
  final String injury;
  final List<int> pain;
  final String painFrom;
  final String painTo;
  final List<DemoPatientSession> sessions;
  final int moreSessions;
  final String legacy;
  final String maskedPhone;
  final String? packageName;
  final int? packageLeft;
  final String? exerciseProgram;
  final int? exerciseCompliance;
  final String? medicalAlert;

  int get painChangePct => pain.isEmpty || pain.first == 0
      ? 0
      : (((pain.last - pain.first) / pain.first) * 100).round();
}

const demoRina = DemoPatientDetail(
  id: 'p0387',
  name: 'Rina Setiawati',
  number: '#0387',
  age: 27,
  gender: 'Perempuan',
  activity: 'Atlet voli',
  height: 165,
  weight: 58,
  injury: 'Ankle kiri · inversion sprain',
  pain: [8, 7, 5, 4, 3, 2],
  painFrom: '1 Sep',
  painTo: '6 Okt',
  packageName: 'Cedera Ringan 5×',
  packageLeft: 1,
  exerciseProgram: 'Program ankle',
  exerciseCompliance: 86,
  sessions: [
    DemoPatientSession(
      sessionId: 's1',
      date: '6 Okt',
      title: 'Masase cedera · nyeri 3→2',
      caption: 'Dimas · latihan calf raise',
    ),
    DemoPatientSession(
      sessionId: 'h-r2',
      date: '29 Sep',
      title: 'Masase cedera + kinesio · 4→3',
      caption: 'Dimas',
    ),
    DemoPatientSession(
      sessionId: 'h-r3',
      date: '22 Sep',
      title: 'Adjustment ankle · 5→4',
      caption: 'Fajar',
    ),
  ],
  moreSessions: 3,
  legacy:
      '14 Mar 2025 · Keluhan: nyeri lutut kanan saat lompat · Treatment: masase, kompres · Kesimpulan: kontrol 2 minggu · Terapis: Fajar',
  maskedPhone: '08••••••4417',
);

const demoAndi = DemoPatientDetail(
  id: 'p0412',
  name: 'Andi Pratama',
  number: '#0412',
  age: 38,
  gender: 'Laki-laki',
  activity: 'Futsal',
  height: 172,
  weight: 70,
  injury: 'Lumbal · LBP menjalar ke paha kanan',
  pain: [8, 8, 7],
  painFrom: '22 Sep',
  painTo: '6 Okt',
  medicalAlert: 'Riwayat LBP kronis — hindari tekanan kuat di L4–L5.',
  sessions: [
    DemoPatientSession(
      sessionId: 's8',
      date: '29 Sep',
      title: 'Adjustment · nyeri 8→7',
      caption: 'Dimas · latihan rumah',
    ),
  ],
  moreSessions: 0,
  legacy:
      '14 Agu 2025 · Keluhan: pinggang kaku setelah main futsal · Treatment: masase, infrared · Kesimpulan: istirahat 3 hari · Terapis: Dimas',
  maskedPhone: '08••••••0412',
);

DemoPatientDetail demoPatient(String id) =>
    id == demoAndi.id ? demoAndi : demoRina;

/// Detail sesi selesai (TR-08).
class DemoSessionDetail {
  const DemoSessionDetail({
    required this.patient,
    required this.when,
    required this.complaint,
    required this.areas,
    required this.painBefore,
    required this.painAfter,
    required this.treatments,
    required this.analysis,
    required this.conclusion,
    required this.editHoursLeft,
    required this.changes,
  });

  final String patient;
  final String when;
  final String complaint;
  final String areas;
  final int painBefore;
  final int painAfter;
  final String treatments;
  final String analysis;
  final String conclusion;

  /// Batas edit oleh pembuat (usulan 24 jam, workshop §16 no. 7).
  final int editHoursLeft;
  final List<(String, String)> changes;
}

const demoRinaSession = DemoSessionDetail(
  patient: 'Rina Setiawati',
  when: 'Sel, 6 Okt · 09.00–09.48 · Dimas',
  complaint: 'Ankle kiri kaku pagi hari',
  areas: 'Ankle kiri, betis kiri',
  painBefore: 3,
  painAfter: 2,
  treatments: 'Masase cedera, stretching',
  analysis: 'ROM dorsofleksi membaik, edema minimal.',
  conclusion: 'Lanjut calf raise 3×12, kontrol Kamis.',
  editHoursLeft: 22,
  changes: [
    ('Dibuat oleh Dimas', '09.48'),
    ('Diedit: nyeri sesudah 3 → 2', '09.51'),
  ],
);

enum DemoSlot { free, session, homeVisit, unavailable }

/// Grid jadwal minggu TR-02: jam 08–16 × Sen–Sab (sesuai mockup).
const demoWeekGrid = <List<DemoSlot>>[
  [
    DemoSlot.session,
    DemoSlot.free,
    DemoSlot.session,
    DemoSlot.free,
    DemoSlot.session,
    DemoSlot.free,
  ],
  [
    DemoSlot.session,
    DemoSlot.session,
    DemoSlot.session,
    DemoSlot.session,
    DemoSlot.free,
    DemoSlot.session,
  ],
  [
    DemoSlot.free,
    DemoSlot.session,
    DemoSlot.free,
    DemoSlot.session,
    DemoSlot.session,
    DemoSlot.session,
  ],
  [
    DemoSlot.session,
    DemoSlot.session,
    DemoSlot.unavailable,
    DemoSlot.free,
    DemoSlot.session,
    DemoSlot.free,
  ],
  [
    DemoSlot.unavailable,
    DemoSlot.unavailable,
    DemoSlot.unavailable,
    DemoSlot.unavailable,
    DemoSlot.unavailable,
    DemoSlot.unavailable,
  ],
  [
    DemoSlot.homeVisit,
    DemoSlot.homeVisit,
    DemoSlot.free,
    DemoSlot.session,
    DemoSlot.free,
    DemoSlot.homeVisit,
  ],
  [
    DemoSlot.homeVisit,
    DemoSlot.homeVisit,
    DemoSlot.session,
    DemoSlot.session,
    DemoSlot.free,
    DemoSlot.homeVisit,
  ],
  [
    DemoSlot.session,
    DemoSlot.session,
    DemoSlot.session,
    DemoSlot.free,
    DemoSlot.session,
    DemoSlot.free,
  ],
  [
    DemoSlot.free,
    DemoSlot.free,
    DemoSlot.session,
    DemoSlot.session,
    DemoSlot.free,
    DemoSlot.free,
  ],
];

// Data contoh aplikasi pasien — diambil dari mockup (design/screens/PS-*.png).
// Hanya ilustrasi (CLAUDE.md); nanti diganti data dari API pasien.

class DemoExercise {
  DemoExercise({
    required this.id,
    required this.name,
    required this.dose,
    required this.doseLong,
    required this.when,
    required this.steps,
    this.doneAt,
    this.duration = '0:48',
  });

  final String id;
  final String name;

  /// "3×12".
  final String dose;

  /// "3 set × 12 kali" (judul detail latihan).
  final String doseLong;

  /// "pagi & sore".
  final String when;
  final List<String> steps;
  final String duration;
  String? doneAt;
  bool get done => doneAt != null;
}

/// Latihan hari ini (dibagi antar layar agar centang di Beranda & Latihan sama).
final demoExercises = [
  DemoExercise(
    id: 'ankle-alphabet',
    name: 'Ankle alphabet',
    dose: '2 set',
    doseLong: '2 set · huruf A–Z',
    when: 'pagi',
    doneAt: '07.12',
    steps: const [
      'Duduk di kursi, angkat kaki kiri sedikit dari lantai.',
      'Tuliskan huruf A sampai Z di udara dengan ujung jari kaki.',
      'Gerakkan dari pergelangan, bukan dari lutut. Ulangi 2 set.',
    ],
  ),
  DemoExercise(
    id: 'calf-raise',
    name: 'Calf raise',
    dose: '3×12',
    doseLong: '3 set × 12 kali',
    when: 'pagi & sore',
    steps: const [
      'Berdiri tegak, pegang dinding untuk keseimbangan.',
      'Angkat tumit perlahan hingga berjinjit, tahan 2 detik.',
      'Turunkan perlahan. Ulangi 12 kali, istirahat 30 detik antar set.',
    ],
  ),
  DemoExercise(
    id: 'single-leg-stand',
    name: 'Single-leg stand',
    dose: '3×30 detik',
    doseLong: '3 × 30 detik',
    when: 'pagi',
    duration: '0:35',
    steps: const [
      'Berdiri di dekat dinding atau kursi untuk pegangan.',
      'Angkat kaki kanan, tumpu pada kaki kiri selama 30 detik.',
      'Turunkan, istirahat 20 detik. Ulangi 3 kali.',
    ],
  ),
];

DemoExercise exerciseById(String id) =>
    demoExercises.firstWhere((e) => e.id == id, orElse: () => demoExercises[1]);

/// Paket yang bisa dibeli (PS-14). Harga & "hemat" sama dengan KS-12.
typedef DemoPackage = ({
  String id,
  String name,
  String detail,
  int price,
  int? saving,
  bool best,
});

const demoPackages = <DemoPackage>[
  (
    id: 'cr5',
    name: 'Cedera Ringan 5×',
    detail: '5 sesi masase cedera ringan · berlaku 60 hari',
    price: 625000,
    saving: 125000,
    best: false,
  ),
  (
    id: 'cr10',
    name: 'Cedera Ringan 10×',
    detail: '10 sesi · berlaku 120 hari',
    price: 1150000,
    saving: 350000,
    best: true,
  ),
  (
    id: 'member',
    name: 'Member Tahunan',
    detail: 'Potongan 10% semua layanan selama 1 tahun',
    price: 300000,
    saving: null,
    best: false,
  ),
];

const demoPoints = 240;
const demoPointValue = 100; // Rp per poin (contoh mockup OW-13)

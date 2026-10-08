import '../../ui/feedback/app_error.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../sync/outbox.dart';
import '../sync/sync_engine.dart';
import 'remote.dart';

/// "Server" contoh di memori untuk mode mock (API_URL kosong).
/// Nama, angka, & harga mengikuti mockup — hanya contoh, bukan data asli (CLAUDE.md).
class MockBackend {
  MockBackend({
    DateTime? today,
    this.latency = const Duration(milliseconds: 350),
  }) : today = _dateOnly(today ?? DateTime.now()) {
    _seed();
  }

  final DateTime today;
  final Duration latency;

  /// Simulasi tanpa sinyal — diubah dari Akun (build debug) untuk mencoba mode offline.
  bool offline = false;

  final patients = <String, Patient>{};
  final sessions = <String, Session>{};
  final records = <String, SessionRecord>{};
  final legacy = <String, List<LegacyRecord>>{};
  final services = <Service>[];
  final invoices = <String, Invoice>{};

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> wait() async {
    await Future<void>.delayed(latency);
    if (offline) throw const AppError(ErrorCode.networkOffline);
  }

  // ── Data contoh ──────────────────────────────────────────────────────────

  static const therapists = {
    'u1': 'Dimas',
    'u4': 'Laras',
    'u3': 'Rudi',
    't-fajar': 'Fajar',
  };

  void _seed() {
    services.addAll(const [
      Service(
        id: 'adj',
        name: 'Adjustment Therapy',
        durationMin: 60,
        price: 250000,
      ),
      Service(
        id: 'mcr',
        name: 'Masase Cedera Ringan',
        durationMin: 60,
        price: 150000,
      ),
      Service(id: 'mcd', name: 'Masase Cedera', durationMin: 75, price: 200000),
      Service(
        id: 'rlx',
        name: 'Relaksasi Premium',
        durationMin: 90,
        price: 300000,
      ),
    ]);

    DateTime at(int dayOffset, int h, int m) =>
        today.add(Duration(days: dayOffset, hours: h, minutes: m));
    final y = today.year;

    void patient(Patient p) => patients[p.id] = p;
    patient(
      Patient(
        id: 'p0387',
        number: 387,
        name: 'Rina Setiawati',
        birthDate: DateTime(1990, 3, 12),
        birthPlace: 'Malang',
        phone: '081234560387',
        address: 'Jl. Bunga Merak 12, Lowokwaru',
        gender: Gender.female,
        hobby: 'Lari pagi',
        heightCm: 160,
        weightKg: 54,
        activePackage: const PackageSummary(
          name: 'Cedera Ringan 5×',
          remaining: 1,
          total: 5,
        ),
        lastVisitAt: at(0, 9, 0),
      ),
    );
    patient(
      Patient(
        id: 'p0412',
        number: 412,
        name: 'Andi Pratama',
        birthDate: DateTime(1988, 7, 2),
        birthPlace: 'Surabaya',
        phone: '081298760412',
        address: 'Jl. Kawi 8, Klojen',
        gender: Gender.male,
        institution: 'PT Sinar Jaya',
        hobby: 'Futsal',
        heightCm: 172,
        weightKg: 70,
        medicalAlert: 'Riwayat LBP kronis — hindari tekanan kuat di L4–L5.',
        lastVisitAt: at(-7, 10, 30),
      ),
    );
    patient(
      Patient(
        id: 'p0201',
        number: 201,
        name: 'Budi Hartono',
        birthDate: DateTime(1965, 1, 20),
        phone: '081311110201',
        address: 'Jl. Sukun Pondok Indah B-4, Sukun',
        gender: Gender.male,
        hobby: 'Berkebun',
        heightCm: 168,
        weightKg: 75,
        lastVisitAt: at(-34, 13, 0),
      ),
    );
    patient(
      Patient(
        id: 'p0413',
        number: 413,
        name: 'Sari Wulandari',
        birthDate: DateTime(1996, 11, 5),
        phone: '085700000413',
        gender: Gender.female,
        heightCm: 158,
        weightKg: 50,
      ),
    );
    patient(
      Patient(
        id: 'p0398',
        number: 398,
        name: 'Dewi Lestari',
        birthDate: DateTime(1993, 6, 18),
        phone: '081277770398',
        gender: Gender.female,
        hobby: 'Yoga',
        activePackage: const PackageSummary(
          name: 'Masase Cedera 10×',
          remaining: 6,
          total: 10,
        ),
        lastVisitAt: at(-3, 11, 0),
      ),
    );
    const extra = [
      'Agus Salim',
      'Bella Kartika',
      'Citra Ayu',
      'Dedi Kurniawan',
      'Eka Putri',
      'Fajar Nugroho',
      'Gita Permata',
      'Hendra Wijaya',
      'Indah Sari',
      'Joko Susilo',
      'Kurnia Dewi',
      'Lukman Hakim',
      'Maya Anggraini',
      'Nanda Pratiwi',
      'Oki Setiawan',
      'Putri Ramadhani',
      'Rizky Maulana',
      'Siti Aminah',
      'Teguh Prakoso',
      'Utami Rahayu',
      'Vina Oktaviani',
      'Wahyu Hidayat',
      'Yoga Saputra',
      'Zahra Nabila',
    ];
    for (final (i, name) in extra.indexed) {
      final n = 300 + i * 3;
      patient(
        Patient(
          id: 'p${n.toString().padLeft(4, '0')}',
          number: n,
          name: name,
          birthDate: DateTime(y - 25 - i, (i % 12) + 1, (i % 27) + 1),
          phone: '0812000${n.toString().padLeft(5, '0')}',
          gender: i.isEven ? Gender.male : Gender.female,
          lastVisitAt: at(-(5 + i * 4), 10, 0),
        ),
      );
    }

    void session(Session s) => sessions[s.id] = s;
    Session make(
      String id,
      Patient p,
      String therapistId,
      Service svc,
      DateTime start,
      SessionStatus status, {
      String? room,
      HomeVisit? homeVisit,
      bool isNew = false,
      String? note,
      String branch = 'pusat',
    }) => Session(
      id: id,
      patientId: p.id,
      patientName: p.name,
      patientNumber: p.number,
      therapistId: therapistId,
      therapistName: therapists[therapistId]!,
      serviceId: svc.id,
      serviceName: svc.name,
      branchId: branch,
      startAt: start,
      durationMin: svc.durationMin,
      status: status,
      room: room,
      homeVisit: homeVisit,
      isNewPatient: isNew,
      note: note,
      startedAt:
          status == SessionStatus.running ||
              status.index >= SessionStatus.done.index
          ? start
          : null,
      endedAt:
          status.index >= SessionStatus.done.index &&
              status != SessionStatus.noShow
          ? start.add(Duration(minutes: svc.durationMin - 12))
          : null,
      arrivedAt: status.index >= SessionStatus.arrived.index
          ? start.subtract(const Duration(minutes: 8))
          : null,
    );

    final adj = services[0],
        mcr = services[1],
        mcd = services[2],
        rlx = services[3];
    final rina = patients['p0387']!,
        andi = patients['p0412']!,
        budi = patients['p0201']!;
    final sari = patients['p0413']!, dewi = patients['p0398']!;

    // Hari ini — sesuai TR-01 & KS-01.
    session(
      make(
        's1',
        rina,
        'u1',
        mcr,
        at(0, 9, 0),
        SessionStatus.unpaid,
        room: 'ruang 1',
        note: 'Cedera ringan · ankle kiri · sesi 4/5',
      ),
    );
    session(
      make(
        's2',
        andi,
        'u1',
        adj,
        at(0, 10, 30),
        SessionStatus.running,
        room: 'ruang 2',
      ),
    );
    session(
      make(
        's3',
        dewi,
        'u4',
        mcd,
        at(0, 11, 0),
        SessionStatus.arrived,
        room: 'ruang 1',
      ),
    );
    session(
      make(
        's4',
        budi,
        'u1',
        rlx,
        at(0, 13, 0),
        SessionStatus.scheduled,
        homeVisit: const HomeVisit(
          address: 'Jl. Sukun Pondok Indah B-4, Sukun',
          landmark: 'Pagar hijau, sebelah musala',
          distanceKm: 4.2,
        ),
      ),
    );
    session(
      make(
        's5',
        sari,
        'u1',
        mcr,
        at(0, 15, 0),
        SessionStatus.arrived,
        isNew: true,
        note: 'Intake via QR · keluhan LBP',
      ),
    );
    session(
      make(
        's6',
        patients['p0303']!,
        'u3',
        adj,
        at(0, 16, 0),
        SessionStatus.scheduled,
        room: 'ruang 2',
      ),
    );
    session(
      make(
        's7',
        patients['p0306']!,
        't-fajar',
        mcd,
        at(0, 14, 0),
        SessionStatus.scheduled,
        room: 'ruang 3',
      ),
    );
    // Kemarin & besok — untuk jadwal minggu & riwayat.
    session(
      make(
        's8',
        andi,
        'u1',
        adj,
        at(-7, 10, 30),
        SessionStatus.paid,
        room: 'ruang 2',
      ),
    );
    session(
      make(
        's9',
        dewi,
        'u4',
        mcd,
        at(-3, 11, 0),
        SessionStatus.paid,
        room: 'ruang 1',
      ),
    );
    session(
      make(
        's10',
        patients['p0309']!,
        'u1',
        mcr,
        at(-1, 9, 30),
        SessionStatus.paid,
        room: 'ruang 1',
      ),
    );
    session(
      make(
        's11',
        patients['p0312']!,
        'u1',
        adj,
        at(-1, 13, 0),
        SessionStatus.noShow,
        room: 'ruang 2',
      ),
    );
    session(
      make(
        's12',
        rina,
        'u1',
        mcr,
        at(1, 9, 0),
        SessionStatus.scheduled,
        room: 'ruang 1',
        note: 'sesi 5/5',
      ),
    );
    session(
      make(
        's13',
        patients['p0315']!,
        'u1',
        adj,
        at(2, 10, 0),
        SessionStatus.awaitingConfirmation,
      ),
    );
    session(
      make(
        's14',
        patients['p0318']!,
        'u1',
        mcr,
        at(0, 10, 0),
        SessionStatus.scheduled,
        room: 'ruang 1',
        branch: 'batu',
      ),
    );

    // Rekam sesi minggu lalu untuk Andi → prefill TR-04.
    records['r-s8'] = SessionRecord(
      id: 'r-s8',
      sessionId: 's8',
      patientId: andi.id,
      therapistId: 'u1',
      complaint: 'Nyeri pinggang bawah menjalar ke paha kanan',
      cause: InjuryCause.work,
      injuryDuration: 3,
      injuryDurationUnit: DurationUnit.month,
      treatedAreas: const [
        'lower-back:left',
        'lower-back:right',
        'deltoids:right',
      ],
      calmingAreas: const [
        'upper-back:left',
        'upper-back:right',
        'quadriceps:right',
      ],
      painBefore: 8,
      painAfter: 7,
      analysis: 'Ketegangan paravertebral kanan, ROM fleksi terbatas.',
      analysisTags: const ['Spasme otot', 'Saraf terjepit ringan'],
      treatments: const ['Adjustment', 'Infrared'],
      conclusion: 'Kontrol 1 minggu, latihan rumah.',
      conclusionTags: const ['Kontrol 1 minggu', 'Latihan rumah'],
      version: 1,
      updatedAt: at(-7, 11, 40),
    );
    legacy[andi.id] = [
      LegacyRecord(
        date: DateTime(y - 1, 8, 14),
        fields: const {
          'Keluhan': 'Pinggang kaku setelah main futsal',
          'Penyebab': 'Olahraga',
          'Lama cedera': '2 minggu',
          'Bagian': 'Pinggang',
          'Bagian penenang': 'Punggung atas',
          'Analisa': 'Otot pinggang tegang',
          'Treatment': 'Masase, infrared',
          'Kesimpulan': 'Istirahat 3 hari',
          'Hasil rontgen': '-',
        },
      ),
    ];

    invoices['s2'] = Invoice(
      id: 'inv-s2',
      sessionId: 's2',
      patientId: andi.id,
      status: PaymentStatus.unpaid,
      items: const [
        InvoiceItem(label: 'Adjustment Therapy', amount: 250000),
        InvoiceItem(label: 'Masase cedera ringan · 1 titik', amount: 150000),
        InvoiceItem(label: 'Tambahan cedera', amount: 100000),
      ],
      adjustments: const [
        InvoiceAdjustment(
          kind: AdjustmentKind.member,
          label: 'Harga member 10%',
          amount: 50000,
        ),
      ],
    );
    invoices['s1'] = Invoice(
      id: 'inv-s1',
      sessionId: 's1',
      patientId: rina.id,
      status: PaymentStatus.unpaid,
      items: const [InvoiceItem(label: 'Masase Cedera Ringan', amount: 150000)],
    );
  }
}

/// [OneLotusRemote] di atas [MockBackend].
class MockRemote implements OneLotusRemote {
  MockRemote(this.backend, {required this.currentUserId});

  final MockBackend backend;

  /// Terapis login — untuk "Pasien saya" (TR-06).
  final String? Function() currentUserId;

  @override
  Future<List<Session>> sessions({
    required String branchId,
    required DateTime from,
    required DateTime to,
    String? therapistId,
  }) async {
    await backend.wait();
    return backend.sessions.values
        .where(
          (s) =>
              s.branchId == branchId &&
              !s.startAt.isBefore(from) &&
              s.startAt.isBefore(to) &&
              (therapistId == null || s.therapistId == therapistId),
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  @override
  Future<Page<Patient>> searchPatients({
    required String query,
    required int page,
    required bool mineOnly,
  }) async {
    await backend.wait();
    final q = query.trim().toLowerCase().replaceFirst('#', '');
    final mine = mineOnly
        ? backend.sessions.values
              .where((s) => s.therapistId == currentUserId())
              .map((s) => s.patientId)
              .toSet()
        : null;
    final digits = RegExp(r'^\d+$').hasMatch(q);
    final all =
        backend.patients.values.where((p) {
          if (mine != null && !mine.contains(p.id)) return false;
          if (q.isEmpty) return true;
          if (digits) {
            return p.number == int.parse(q) ||
                (q.length == 4 && (p.phone?.endsWith(q) ?? false));
          }
          return p.name.toLowerCase().contains(q);
        }).toList()..sort(
          (a, b) => (b.lastVisitAt ?? DateTime(1970)).compareTo(
            a.lastVisitAt ?? DateTime(1970),
          ),
        );
    final start = (page - 1) * Page.size;
    final items = all.skip(start).take(Page.size).toList();
    return Page(
      items: items,
      page: page,
      hasMore: start + items.length < all.length,
    );
  }

  @override
  Future<Patient> patient(String id) async {
    await backend.wait();
    final p = backend.patients[id];
    if (p == null) throw const AppError(ErrorCode.notFound);
    return p;
  }

  @override
  Future<SessionRecord?> recordForSession(String sessionId) async {
    await backend.wait();
    return backend.records.values
        .where((r) => r.sessionId == sessionId)
        .firstOrNull;
  }

  @override
  Future<SessionRecord?> latestRecordForPatient(String patientId) async {
    final page = await recordHistory(patientId, page: 1);
    return page.items.firstOrNull;
  }

  @override
  Future<Page<SessionRecord>> recordHistory(
    String patientId, {
    required int page,
  }) async {
    await backend.wait();
    final all =
        backend.records.values.where((r) => r.patientId == patientId).toList()
          ..sort(
            (a, b) => (b.updatedAt ?? DateTime(1970)).compareTo(
              a.updatedAt ?? DateTime(1970),
            ),
          );
    final start = (page - 1) * Page.size;
    final items = all.skip(start).take(Page.size).toList();
    return Page(
      items: items,
      page: page,
      hasMore: start + items.length < all.length,
    );
  }

  @override
  Future<List<LegacyRecord>> legacyRecords(String patientId) async {
    await backend.wait();
    return backend.legacy[patientId] ?? const [];
  }

  @override
  Future<List<Service>> services({required String branchId}) async {
    await backend.wait();
    return List.of(backend.services);
  }

  @override
  Future<Invoice?> invoiceForSession(String sessionId) async {
    await backend.wait();
    return backend.invoices[sessionId];
  }
}

/// Pengirim outbox untuk mode mock: menerapkan perubahan ke [MockBackend]
/// dengan aturan versi yang sama seperti server (409 bila versi dasar tertinggal).
class MockOutboxSender implements OutboxSender {
  MockOutboxSender(this.backend);

  final MockBackend backend;

  @override
  Future<SendOutcome> send(OutboxItem item) async {
    try {
      await backend.wait();
    } on AppError catch (e) {
      return SendError(e);
    }
    switch (item.kind) {
      case OutboxKinds.sessionRecordUpsert:
        final incoming = SessionRecord.fromJson(item.payload);
        final current = backend.records[incoming.id];
        if (current != null && item.baseVersion < current.version) {
          return SendConflict(
            serverPayload: current.toJson(),
            serverVersion: current.version,
          );
        }
        final saved = incoming.copyWith(
          version: (current?.version ?? 0) + 1,
          updatedAt: DateTime.now(),
        );
        backend.records[saved.id] = saved;
        return SendOk(serverVersion: saved.version, response: saved.toJson());
      case OutboxKinds.sessionStatus:
        final s = backend.sessions[item.entityId];
        if (s == null) return const SendError(AppError(ErrorCode.notFound));
        final status = SessionStatus.fromApi(item.payload['status'] as String?);
        final at = DateTime.tryParse(
          item.payload['at'] as String? ?? '',
        )?.toLocal();
        backend.sessions[s.id] = s.copyWith(
          status: status,
          arrivedAt: status == SessionStatus.arrived ? at : null,
          startedAt: status == SessionStatus.running ? at : null,
          endedAt: status == SessionStatus.done ? at : null,
        );
        return SendOk(response: backend.sessions[s.id]!.toJson());
      default:
        return const SendError(AppError(ErrorCode.unknown));
    }
  }
}

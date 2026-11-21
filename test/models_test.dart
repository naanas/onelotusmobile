import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/data/models.dart';

import 'support/fake_api.dart';

void main() {
  test('Pasien.fromJson membaca kolom Laravel', () {
    final p = Pasien.fromJson(pasienJson());
    expect(p.nomor, 1362);
    expect(p.ttl, DateTime(1990, 5, 1));
    expect(p.tlp, '081234567890');
    expect(p.tb, 172);
    expect(p.kunjunganTerakhir, DateTime(2026, 11, 3));
  });

  test('tlp null untuk terapis', () {
    expect(Pasien.fromJson(pasienJson(withTlp: false)).tlp, isNull);
  });

  test('jenis kelamin data lama', () {
    expect(genderLabel('L'), 'Laki-laki');
    expect(genderLabel('P'), 'Perempuan');
    expect(genderLabel('Laki - Laki'), 'Laki - Laki');
    expect(genderCode('Laki - Laki'), 'L');
    expect(genderCode('Perempuan'), 'P');
    expect(genderCode('x'), isNull);
  });

  test('PerawatanDraft.toJson memakai nama kolom backend', () {
    final j = PerawatanDraft(
      keluhan: 'Nyeri',
      lamaCedera: '2 minggu',
      tglPeriksa: DateTime(2026, 11, 3),
    ).toJson();
    expect(j['keluhan'], 'Nyeri');
    expect(j['lama_cedera'], '2 minggu');
    expect(j['tgl_periksa'], '2026-11-03');
  });

  test('ym & ymd', () {
    expect(ym(DateTime(2026, 2)), '2026-02');
    expect(ymd(DateTime(2026, 2, 5)), '2026-02-05');
  });

  test('Role', () {
    expect(Role.parse('admin'), Role.admin);
    expect(Role.parse('user'), Role.user);
    expect(Role.user.label, 'Terapis');
  });
}

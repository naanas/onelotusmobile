import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onelotus_staff/data/pasien/pasien_app_api.dart';
import 'package:onelotus_staff/pasien/booking/booking_request_card.dart';

import '../helpers.dart';

BookingRequestV _req(Map<String, dynamic> extra) => BookingRequestV.fromJson({
  'id': 'b1',
  'status': 'pending',
  'location_type': 'home_visit',
  'service_name': 'Terapi Rumah',
  'duration_min': 60,
  'requested_start': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
  'address': 'Jl. Mawar 2, Malang',
  'estimate': {
    'distance_km': 4.3,
    'transport_fee': 25000,
    'rate_per_km': 5000,
    'service_price': 200000,
    'total': 225000,
    'in_area': true,
  },
  ...extra,
});

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('menunggu konfirmasi: alamat + rincian biaya home visit', (t) async {
    await t.pumpWidget(TestApp(child: BookingRequestCard(request: _req({}), onChange: () {})));
    expect(find.text('Menunggu konfirmasi klinik'), findsOneWidget);
    expect(find.text('Jl. Mawar 2, Malang'), findsOneWidget);
    expect(find.text('Transport (4,3 km × Rp5.000)'), findsOneWidget);
    expect(find.text('Rp25.000'), findsOneWidget);
    expect(find.text('Rp225.000'), findsOneWidget);
    expect(find.text('Ubah / batalkan'), findsOneWidget);
    expect(find.text('Terima jam usulan'), findsNothing);
  });

  testWidgets('usulan jam lain: tombol terima memanggil onAccept', (t) async {
    var accepted = false;
    final proposed = DateTime.now().add(const Duration(days: 3));
    await t.pumpWidget(
      TestApp(
        child: BookingRequestCard(
          request: _req({'status': 'proposed', 'proposed_start': proposed.toUtc().toIso8601String()}),
          onAccept: () => accepted = true,
          onChange: () {},
        ),
      ),
    );
    expect(find.text('Klinik usul jam lain'), findsOneWidget);
    expect(find.textContaining('Anda meminta'), findsOneWidget);
    await t.tap(find.text('Terima jam usulan'));
    expect(accepted, isTrue);
  });

  testWidgets('ditolak: alasan klinik tampil, tanpa rincian biaya', (t) async {
    await t.pumpWidget(
      TestApp(
        child: BookingRequestCard(
          request: _req({'status': 'rejected', 'reject_reason': 'Terapis penuh di hari itu'}),
          onRebook: () {},
        ),
      ),
    );
    expect(find.text('Tidak dapat diterima'), findsOneWidget);
    expect(find.text('Alasan klinik: Terapis penuh di hari itu'), findsOneWidget);
    expect(find.text('PERKIRAAN BIAYA'), findsNothing);
    expect(find.text('Booking jadwal lain'), findsOneWidget);
  });
}

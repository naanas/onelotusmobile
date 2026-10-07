import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelotus_staff/ui/ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('OlButton: loading & nonaktif tidak bisa diketuk', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      TestApp(
        child: Column(
          children: [
            OlButton(label: 'Aktif', onPressed: () => taps++),
            OlButton(label: 'Proses', loading: true, onPressed: () => taps++),
            const OlButton(label: 'Mati', onPressed: null),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Aktif'));
    await tester.tap(find.byType(OlButton).at(1));
    await tester.tap(find.text('Mati'));
    expect(taps, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('OlTextField: error inline & tombol tampilkan password', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        child: const Column(
          children: [
            OlTextField(
              label: 'Berat badan',
              error: 'Berat badan harus angka, mis. 58',
            ),
            OlTextField(label: 'Password', obscure: true, isRequired: true),
          ],
        ),
      ),
    );
    expect(find.text('Berat badan harus angka, mis. 58'), findsOneWidget);
    expect(find.byTooltip('Tampilkan password'), findsOneWidget);
    await tester.tap(find.byTooltip('Tampilkan password'));
    await tester.pump();
    expect(find.byTooltip('Sembunyikan password'), findsOneWidget);
  });

  testWidgets('Toast: maksimal 1, yang baru menggantikan', (tester) async {
    final app = TestApp(child: const SizedBox());
    await tester.pumpWidget(app);
    app.feedback.success('Pertama');
    await tester.pump();
    app.feedback.info('Kedua');
    await tester.pumpAndSettle();
    expect(find.text('Pertama'), findsNothing);
    expect(find.text('Kedua'), findsOneWidget);
  });

  testWidgets('Toast error menampilkan Ref & Coba lagi', (tester) async {
    final app = TestApp(child: const SizedBox());
    await tester.pumpWidget(app);
    var retried = false;
    expect(
      app.feedback.error(
        const AppError(ErrorCode.serverError, refId: 'OL-7F3A'),
        retry: () => retried = true,
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ref: OL-7F3A'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    expect(retried, isTrue);
  });

  testWidgets('Error inline dikembalikan ke layar', (tester) async {
    final app = TestApp(child: const SizedBox());
    await tester.pumpWidget(app);
    expect(app.feedback.error(const AppError(ErrorCode.validation)), isFalse);
  });

  testWidgets('Dialog dengan alasan: tombol utama aktif setelah alasan diisi', (
    tester,
  ) async {
    final app = TestApp(child: const SizedBox());
    await tester.pumpWidget(app);
    final result = app.feedback.choose(
      const ConfirmSpec(
        title: 'Batalkan transaksi Rp450.000?',
        message: '',
        confirmLabel: 'Batalkan transaksi',
        reasonLabel: 'Alasan',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan transaksi'));
    await tester.pumpAndSettle();
    expect(
      find.text('Batalkan transaksi Rp450.000?'),
      findsOneWidget,
    ); // masih terbuka

    await tester.enterText(find.byType(TextFormField), 'Salah input layanan');
    await tester.pump();
    await tester.tap(find.text('Batalkan transaksi'));
    await tester.pumpAndSettle();
    final r = await result;
    expect(r.confirmed, isTrue);
    expect(r.reason, 'Salah input layanan');
  });

  testWidgets('Hanya 1 dialog pada satu waktu', (tester) async {
    final app = TestApp(child: const SizedBox());
    await tester.pumpWidget(app);
    const spec = ConfirmSpec(title: 'A?', message: '', confirmLabel: 'Ya A');
    app.feedback.confirm(spec);
    await tester.pumpAndSettle();
    final second = await app.feedback.choose(spec);
    expect(second.choice, ConfirmChoice.cancel);
    expect(find.text('A?'), findsOneWidget);
  });

  testWidgets('Banner: id sama menggantikan, clear menghapus', (tester) async {
    final app = TestApp(child: const FeedbackBannerHost());
    await tester.pumpWidget(app);
    app.feedback.error(const AppError(ErrorCode.networkOffline));
    app.feedback.error(const AppError(ErrorCode.networkOffline));
    await tester.pumpAndSettle();
    expect(
      find.text('Kamu sedang offline. Data tersimpan di HP.'),
      findsOneWidget,
    );
    app.feedback.clearBanner('network_offline');
    await tester.pumpAndSettle();
    expect(find.byType(OlBanner), findsNothing);
  });

  test('OlIcons: 72 ikon sesuai spec D.1', () {
    expect(OlIcons.all.length, 72);
    expect(OlIcons.all.map((i) => i.name).toSet().length, 72);
  });

  test('OlAvatar.initialsOf', () {
    expect(OlAvatar.initialsOf('Andi Pratama'), 'AP');
    expect(OlAvatar.initialsOf('dimas'), 'D');
    expect(OlAvatar.initialsOf('Rina Dewi Setiawati'), 'RS');
    expect(OlAvatar.initialsOf('  '), '?');
  });
}

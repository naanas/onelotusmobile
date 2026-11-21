# One Lotus Mobile — konteks proyek

Aplikasi mobile untuk staf One Lotus Personal Therapy (Malang): admin & terapis. Fitur = sistem Laravel lama.
Backend: One Lotus API (Go) di `../backendonelotusmobile`, database Supabase dengan struktur tabel Laravel.

## Sumber kebenaran
- `docs/onelotus-mobile-ui-enhancement.md` — kini hanya acuan **tampilan** (fitur ikut Laravel). Token desain §2, komponen §4, layar §5,
  alur end-to-end §6 (pembayaran §6.4), matriks akses §7, offline §8, aksesibilitas §9, privasi §10,
  microcopy §11 (staf pakai "kamu", pasien pakai "Anda"), feedback/popup/error §12, Definition of Done §14,
  katalog 90 layar Lampiran A, aset & animasi Lampiran D (termasuk BodyMap D.2b).
- `design/screens/<ID>.png` — tampilan final tiap layar (ID sama dengan Lampiran A). `_index.json` = daftar judul.
- `design/source/<ID>.html` — HTML statis tiap layar (buka di browser); `design/source/ol.css` = token & gaya v2.
- `design/bodymap-demo.html` — perilaku & animasi peta tubuh TR-04.
- `assets/` — ikon Phosphor (regular/fill/duotone), ilustrasi unDraw, Lottie, peta tubuh. Lisensi di `assets/README.md`.
- `docs/OneLotus-Mobile-Proposal-dan-UI.pdf` — proposal ke mitra + katalog UI.

## Keputusan yang sudah diambil
- **Aplikasi = sistem Laravel lama, persis** (diputuskan user, 21 Nov 2026; menggantikan semua keputusan sebelumnya
  tentang aplikasi pasien, kasir/owner, jadwal, rekam sesi, home visit, pembayaran, offline). Referensi: `../referensiaja/laravel`.
  - Hanya staf, dua peran: **admin** & **user (terapis)**. Tidak ada aplikasi pasien.
  - Tab: Data Pasien · Rekap · (+ Tambah Pasien) · Formulir · Lainnya (Export Excel, User Management khusus admin, Keluar).
  - Nomor HP pasien hanya untuk admin. Tambah pasien → langsung Tambah Pemeriksaan (seperti Laravel).
  - Kode: `lib/data/` (auth, klinik_api, models — nama kolom = kolom Laravel), `lib/features/` (satu file per layar),
    `lib/router/app_router.dart`. Komponen UI `lib/ui/` & tema `lib/theme/` tetap dipakai.
  - Backend: `../backendonelotusmobile` (`internal/klinik`, `db/schema.sql`). Form pendaftaran publik (pengganti
    Google Form) = Next.js `../formulir-pasien`.
- Flutter SDK project: **3.38.x** (Dart 3.10). Flutter ≥ 3.50 gagal build karena `phosphor_flutter` 2.1.0.
- Android dulu; iOS menyusul dari kode yang sama.

## Aturan kerja
- Ikuti layar di `design/screens` dan aturan di spec; jangan menambah pustaka ikon lain.
- Data di mockup (nama pasien, angka) hanyalah contoh — jangan dimasukkan ke kode aplikasi.
- Aplikasi tidak punya mode mock: semua data dari One Lotus API (`API_URL` di `env/*.json`,
  `flutter run --dart-define-from-file=env/prod.json` atau `env/lokal.json` untuk backend di laptop).
  Server palsu hanya untuk tes (`test/support/fake_api.dart`). Tes kontrak ke backend sungguhan:
  `test/contract/live_api_test.dart` (butuh `--dart-define=LIVE_API=... USERNAME=... PASSWORD=...`).

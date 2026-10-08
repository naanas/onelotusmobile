# Catatan sesi pengembangan — One Lotus Mobile

Ringkasan percakapan dengan Claude Code sampai 8 Okt 2026 (commit `a284b9b`).
Bagian awal sesi sempat diringkas otomatis karena konteks penuh, jadi detail
percakapan awal ditulis sebagai ringkasan, bukan transkrip kata per kata.

---

## 1. Permintaan & arahan dari user (urut waktu)

1. "check claude-cli-playbook.md dan jalankan" → pilih **Flutter (ikuti playbook)**, cakupan **Tahap 0–2**.
2. "lanjutkan" → Tahap 3 (navigasi, login, peran).
3. "udah semua kan code nya?"
4. Menjalankan aplikasi sendiri di HP Android (Samsung SM-F731B) lewat USB dengan `flutter run` — Claude tidak perlu menjalankan emulator.
5. "sempurnakan yang sudah di develop sekarang, splash screen nya kocak, dan animasi perpindahan tab atau screen nya masih belum ada jadi kaku banget, lalu halaman home dengan halaman lain nya background nya kok beda?"
6. "lanjutin pengembangan nya" → Tahap 4 (lapisan data, mock API, offline) + TR-01.
7. **"slacing ui nya dulu aja jangan dulu pikirin backend dan db"** → sejak ini fokus slicing UI dari `design/screens/*.png` dengan data contoh.
8. "gas bikin" → lanjut Kasir, lalu Owner, State, Pasien.
9. "layar state (ST-01 sampai ST-16), lalu aplikasi Pasien (PS-01 sampai PS-20) itu aja langsung, web nya nanti dulu".
10. "oke sekarang save conversation sampe sini di .md" → dokumen ini.

## 2. Keputusan teknis

- **Flutter 3.38.10 / Dart 3.10.9**, dipin karena macOS 13.7 Intel (`~/development/flutter`), JDK 21 (JDK 25 merusak Gradle).
- Riverpod 3, go_router 17 (`StatefulShellRoute` per peran), sqflite untuk outbox/draf/cache.
- Ikon hanya Phosphor (aturan CLAUDE.md); ikon "play" digambar sendiri (`OlPlayGlyph`).
- Font Plus Jakarta Sans & JetBrains Mono (instance statis agar glyph → × ± tersedia).
- **Satu aplikasi untuk staf & pasien** (keputusan akhir sesi; awalnya pasien dibuat sebagai entrypoint terpisah). Belum login → perkenalan pasien dengan tautan "Staf klinik? Masuk di sini"; login staf punya tautan "Pasien? Masuk dengan nomor HP". Rute pasien berawalan `/pasien/`.
- Aturan bisnis yang menunggu workshop mitra (spec §16) **tidak dikarang**: komisi, paket, poin, DP, batas ubah jadwal hanya berupa isian/angka contoh mockup dan ditandai.

## 3. Riwayat commit

| Commit | Isi |
|---|---|
| `1fe6593` | init flutter |
| `a64fbb6` | docs: handoff desain & spec |
| `d95a1ca` | fondasi tema, ikon, widget inti & AppFeedback (Tahap 0–2) |
| `8832489` | navigasi, login & peran (Tahap 3) |
| `f2fb422` | perbaikan splash, transisi layar & tab, tab bar, status bar |
| `e4ecf8c` | lapisan data, mock API & mode offline (Tahap 4) |
| `40ec718` | TR-01 beranda / jadwal hari ini terapis |
| `60369eb` | TR-02, 03, 05, 06, 07, 08 |
| `1d0bdc9` | TR-09 s.d. TR-14 + menu terapis di Akun |
| `bb6d90e`, `46bebcc` | BodyMap + TR-04 rekam sesi |
| `4550ac5` | Umum UM-02, 03, 09–15 |
| `474f2cc` | Kasir KS-01 s.d. KS-10 |
| `2028859` | Kasir KS-11 s.d. KS-18 + menu kasir di Akun |
| `b6ef04c` | Owner OW-01 s.d. OW-20 |
| `a3d2c4d` | Layar state ST-01 s.d. ST-16 |
| `a284b9b` | Aplikasi pasien PS-01 s.d. PS-20 |

## 4. Status per modul

| Modul | Status |
|---|---|
| Umum (UM-01..15) | Selesai |
| Terapis (TR-01..14) | Selesai; TR-01 memakai repository + mock backend (offline) |
| Kasir (KS-01..18) | Selesai (data contoh) |
| Owner (OW-01..20) | Selesai (data contoh) |
| State (ST-01..16) | Selesai; ST-05/06/16 berupa galeri → Akun → Galeri komponen (debug) |
| Pasien (PS-01..20) | Selesai (data contoh, sesi di memori) |
| Web (WB-01..03) | **Belum** — ditunda atas permintaan user |

### Ringkasan sesi terakhir (Kasir → Owner → State → Pasien)

**Kasir** — review screenshot KS-01..18; perbaikan: segmented satu baris (label "Transfer" tidak patah), chip nominal cepat selebar kolom (`OlChip.expand`), placeholder voucher tidak mono. Test login kasir disesuaikan (tombol Keluar perlu di-scroll).

**Owner** — tab Ringkasan (omzet per periode, retensi, okupansi, sesi per terapis, pintasan Kelola), Jadwal (grid per terapis + mingguan), Pasien (lintas cabang, gabung data ganda, pulihkan arsip), Laporan (Omzet/Layanan/Terapis/Retensi/Home visit) + 16 layar kelola (ekspor, persetujuan, rekap & aturan komisi, staf, layanan & harga, paket, voucher, poin & referral, template WA, pustaka latihan, pengumuman, cabang & ruang, audit log, rekonsiliasi, kirim pengingat massal). Owner boleh membuka layar kasir non-tab (piutang, buat jadwal, pindah sesi).

**State** — sheet bersama ST-07 (catatan belum terkirim), ST-08 (pasien ganda), ST-09 (konflik edit) di `lib/ui/feedback/state_sheets.dart`; TR-01: pill header "Memuat…/Gagal memuat", banner offline, pesan hari Minggu; OW-20 memakai dialog ST-13 dengan pratinjau pesan; toggle debug **"Simulasi gangguan server"** di Akun.

**Pasien** — onboarding 3 layar, masuk nomor HP + OTP WhatsApp (kode `000000` = contoh salah), hubungkan data lama (tanggal lahir contoh 12 Mei 1999, maks 3 percobaan), persetujuan data, tab Beranda/Latihan/Booking/Profil, detail latihan, booking 4 langkah, bayar tagihan (QRIS/VA/e-wallet), jadwal saya, ubah/batal jadwal, riwayat sesi versi pasien, paket & pembayaran, beli paket, struk, poin & referral, notifikasi, alamat home visit, hapus akun.

## 5. Komponen bersama yang ditambahkan di sesi terakhir

`OlBarChart`/`OlMeterRow`, `OlSelectField`, `OlPlayGlyph`, `OlDayStrip`, `OlPinMap`, `OlTabShell` (dipisah dari `RoleShell`), `OlChoiceCard`, `showSyncIssuesSheet`, `showDuplicatePatientSheet`, `showConflictSheet`, `OlAppHeader.bottom`, `OlListItem.subtitleWidget`, `OlChip.expand`, `OlDetailScaffold` (`showBack`, `background`, `top`; foot bar di `bottomNavigationBar` agar toast tidak menutupi tombol, kembali ke body saat keyboard terbuka).

## 6. Pelajaran / jebakan yang pernah terjadi

- Bayangan pada `Ink` di dalam `Material` atau di belakang latar transparan → kotak/lingkaran abu. Taruh warna & bayangan di `Container` luar, `Material(type: transparency)` di dalam.
- `Semantics` interaktif perlu `container: true` agar label tidak hilang.
- Riverpod 3 auto-retry menyembunyikan error → `retry: (_, _) => null`.
- Edit berbasis regex Python sering gagal setelah `dart format`; pakai Edit dengan teks persis.
- Screenshot test: toast tampak bergaris hitam tebal karena flutter_test mematikan bayangan — bukan bug aplikasi.

## 7. Cara cek ulang

```sh
export PATH="$HOME/development/flutter/bin:$PATH"
flutter analyze
flutter test                      # unit & widget test
flutter test test_screens --dart-define=SHOT_DIR=/tmp/shots   # render semua layar ke PNG
flutter run                       # satu aplikasi (staf & pasien)
```

Akun contoh (mode mock): `dimas.terapis` / `terapis123`, `sinta.kasir` / `kasir123`, `rudi.owner` / `owner123`.

## 8. Berikutnya

- Sambungkan layar slicing ke API setelah Fase 0 backend siap; jawab 18 pertanyaan workshop (§16).

## 9. Keputusan sesudah catatan awal

- iOS ditunda sampai user membeli Mac baru (MacBook Pro 2017 / macOS 13 tidak bisa Xcode 16+). Build cloud (Codemagic) dibahas, tidak dipakai.
- Web WB-01..03 tidak dikerjakan.
- Staf & pasien digabung jadi **satu aplikasi** (`lib/main.dart` saja; `main_pasien.dart` dihapus).

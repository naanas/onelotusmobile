# Playbook Claude di terminal — One Lotus Mobile (Flutter + emulator Android)

## 0. Persiapan (sekali saja, di Terminal Mac)

```bash
# Flutter SDK (atau unduh zip dari flutter.dev → macOS → Intel)
brew install --cask flutter
flutter doctor                    # cek apa yang kurang
flutter doctor --android-licenses # setujui lisensi Android SDK (ketik y)

# Claude Code (CLI). Cara install terbaru: https://docs.claude.com/en/docs/claude-code/overview
npm install -g @anthropic-ai/claude-code

# Buat project
cd ~/Projects
flutter create --org com.onelotus --platforms android,ios onelotus_staff
cd onelotus_staff
git init && git add -A && git commit -m "chore: init flutter"

# Ekstrak onelotus-handoff.zip, lalu salin ISI folder onelotus-handoff/ ke sini
# (CLAUDE.md, .claude/, docs/, design/, assets/ harus ada di root project)
git add -A && git commit -m "docs: handoff desain & spec"
```

Nama emulator kamu: `flutter emulators` (kolom Id).

## Rutinitas harian (2 tab Terminal)

| Tab | Perintah | Fungsi |
|---|---|---|
| 1 | `flutter emulators --launch <Id>` lalu `flutter run` | Jalankan app di emulator. Tekan `r` = hot reload, `R` = hot restart, `q` = keluar |
| 2 | `claude` | Sesi baru. `claude --continue` = lanjutkan sesi terakhir |

Biarkan emulator & `flutter run` menyala seharian. Setiap Claude selesai mengubah kode, tekan `r` di tab 1.

Perintah buatan di project ini (ketik di dalam Claude):
- `/fase <nama>` — susun rencana tanpa menulis kode. Contoh: `/fase Fase 1 aplikasi terapis`
- `/layar <ID>` — bangun satu layar sesuai desain. Contoh: `/layar TR-01`
- `/cek-layar <ID>` — audit layar terhadap desain, spec & DoD. Contoh: `/cek-layar TR-04`

## 1. Orientasi (sesi pertama)

```
Baca CLAUDE.md, lalu docs/onelotus-mobile-ui-enhancement.md bagian §1–§4, §7, §8, §12, §13 dan Lampiran A.
Lihat beberapa contoh di design/screens (UM-04, TR-01, TR-04, KS-09).
Ringkas dalam 15 poin apa yang kamu pahami tentang aplikasi ini, lalu usulkan struktur folder lib/
(feature-first: lib/theme, lib/ui, lib/data, lib/features/<modul>, lib/router) untuk satu aplikasi staf
dengan menu per peran (terapis, kasir, owner). Jangan menulis kode dulu.
```

## 2. Fondasi: paket, tema, font, ikon, widget

```
Siapkan fondasi:
1) pubspec.yaml: tambahkan paket dari CLAUDE.md (go_router, flutter_riverpod, dio, drift atau sqflite,
   flutter_secure_storage, local_auth, geolocator, image_picker, record, flutter_svg, lottie, phosphor_flutter,
   path_drawing, intl). Daftarkan assets/ (illustrations, lottie, body) dan font dari assets/fonts.
2) lib/theme: ThemeData + ThemeExtension berisi token dari design/source/ol.css dan spec §2
   (latar #F2F5F8, brand #0277B5, brandDeep #0B3B5C, status ok/warn/crit, kartu radius 20, tombol 52dp radius 16).
3) Widget OlIcon yang membungkus phosphor_flutter dengan nama ikon One Lotus dari assets/icons/_index.json
   (contoh: OlIcon.calendar, bobot regular/fill/duotone).
4) Widget inti spec §4 di lib/ui: OlButton (primary/secondary/text/danger, loading, disabled), OlCard (biasa, now/hero, gold),
   OlTextField (label, wajib *, helper, error, fokus), OlChip, OlTag, OlSegmented, OlListItem, OlAvatar,
   OlBanner (info/warn/crit/ok), SyncIndicator, EmptyState (ilustrasi dari assets/illustrations), Skeleton.
5) Sistem feedback §12: toast, dialog konfirmasi, bottom sheet, dengan satu helper (mis. context.feedback.toast(...)).
Buat halaman /dev/komponen yang menampilkan semua widget supaya bisa saya cek di emulator.
Jalankan flutter analyze & flutter test, lalu commit.
```

## 3. Navigasi, login & peran

```
Implementasikan alur umum: UM-01 splash, UM-04 login (+ UM-04b error), UM-05 lupa password, UM-06 PIN,
UM-07 kunci layar, lalu tab bar per peran sesuai §3 dan matriks akses §7
(terapis: Jadwal·Pasien·FAB·Riwayat·Akun; kasir: Antrian·Pasien·FAB·Kasir·Akun; owner: Ringkasan·Jadwal·Pasien·Laporan·Akun).
Pakai go_router dengan redirect berdasarkan status login & peran. Token di flutter_secure_storage.
Login masih ke repository mock dengan 3 akun contoh (terapis, kasir, owner). Kerjakan tiap layar dengan /layar.
```

## 4. Data, mock API & mode offline

```
Buat lapisan data:
1) lib/data/models — Pasien, Sesi/Pemeriksaan, Jadwal, Layanan, Tagihan, User/Peran sesuai spec
   (kolom pemeriksaan lama: keluhan, penyebab, lama_cedera, analisa, treatment, bagian_penenang, kesimpulan, terapis, hasil_rontgen).
2) Repository dengan dua implementasi: ApiRepository (dio ke API_URL dari --dart-define) dan MockRepository
   (data contoh dari desain). Pilih otomatis: API_URL kosong = mock.
3) Riverpod provider untuk tiap repository.
4) Offline §8: database lokal (drift/sqflite) untuk draf rekam sesi + outbox sinkron dengan retry,
   status sinkron global untuk SyncIndicator, penanganan konflik versi seperti ST-09.
Tulis unit test untuk outbox. Commit.
```

## 5. Aplikasi terapis (Fase 1)

Satu per satu, tekan `r` di emulator setelah tiap layar:

```
/layar TR-01
/layar TR-02
/layar TR-05
/layar TR-06
/layar TR-07
/layar TR-08
/layar TR-14
/layar TR-09
```

## 6. Rekam sesi + peta tubuh (TR-04)

```
Bangun widget BodyMap (CustomPainter) dari assets/body/bodymap_paths.json, mengikuti spec Lampiran D.2b
dan perilaku design/bodymap-demo.html (baca script-nya):
- parse path SVG dengan path_drawing (parseSvgPathData), skala dari viewBox ke ukuran widget,
  hit-test ketukan dengan Path.contains; "hair" tidak bisa dipilih.
- mode Ditangani (#0277B5) / Penenang (#F2B263), ketuk untuk pilih/hapus, key = slug + sisi pasien,
  area sama di depan & belakang ikut tertandai, kiri+kanan mode sama jadi satu chip "(kedua sisi)".
- animasi: warna 150ms, denyut skala 1→1.07→1 320ms di bounds otot, label area 1,2 dtk, chip masuk 200ms / keluar 150ms
  (AnimatedList), ketuk chip = kedip, HapticFeedback.selectionClick(), semua mati saat MediaQuery.disableAnimationsOf.
Tambahkan widget test untuk logika pilih/hapus/gabung chip. Lalu /layar TR-04 lengkap: keluhan, BodyMap,
skala nyeri sebelum/sesudah, penyebab, analisa, treatment, foto rontgen, catatan suara, simpan offline + kirim ringkasan.
```

## 7. Intake QR & alur pendukung Fase 1

```
/layar KS-01
/layar KS-02
/layar ST-08
/layar UM-14
```
Lalu galeri state:
```
Implementasikan semua state di design/screens/ST-*.png sebagai widget/varian yang dipakai ulang
(kosong, memuat/skeleton, error, offline, konflik, sesi berakhir, toast, dialog). Pasang di layar yang sudah ada.
```

## 8. Audit sebelum dibagikan

```
Untuk setiap layar Fase 1 yang sudah dibangun, jalankan /cek-layar <ID>.
Setelah itu buat docs/status-fase1.md: tabel ID layar, status, temuan tersisa, TODO workshop.
```

## 9. Build APK untuk staf

```
Siapkan rilis Android: nama aplikasi "One Lotus", applicationId com.onelotus.staff, ikon & splash dari assets
(flutter_launcher_icons, flutter_native_splash), izin lokasi/kamera/mikrofon di AndroidManifest,
keystore rilis (jelaskan langkah membuatnya & simpan key.properties di luar git).
```
```bash
flutter build apk --release
# hasil: build/app/outputs/flutter-apk/app-release.apk → bagikan ke staf via WhatsApp
```

## Tips

- Satu permintaan = satu layar / satu widget. Hasil jauh lebih rapi daripada "buat semua layar".
- Kalau hasil meleset dari desain, screenshot emulator (ikon kamera di panel emulator), drag ke terminal Claude,
  dan sebutkan bagian yang beda.
- `/clear` setiap ganti modul supaya konteks tidak penuh; CLAUDE.md otomatis terbaca lagi.
- Setelah workshop dengan mitra, perbarui CLAUDE.md bagian "Belum final" dan minta Claude mencari semua `TODO(workshop`.
- Emulator lambat? Matikan animasi Android di Developer options, Graphics = Software bila System UI sering macet.

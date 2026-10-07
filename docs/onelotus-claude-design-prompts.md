# One Lotus Mobile — Prompt Claude Design

Kumpulan prompt untuk membuat ulang atau melanjutkan prototipe One Lotus Mobile di Claude Design.
Pakai bersama `onelotus-mobile-ui-enhancement.md` (spesifikasi + katalog 90 layar).

**Cara pakai**
1. Lampirkan `onelotus-mobile-ui-enhancement.md` di chat.
2. Kirim **Prompt 0 (Konteks)** sekali di awal.
3. Kirim prompt batch satu per satu (1 → 7). Tunggu satu batch selesai dan direview sebelum lanjut.
4. Untuk revisi, pakai **Prompt R** di bagian akhir.

---

## Prompt 0 — Konteks & aturan visual

```
Kamu akan mendesain prototipe aplikasi mobile "One Lotus Mobile" untuk klinik
fisioterapi & terapi cedera One Lotus Personal Therapy (Malang). Spesifikasi
lengkap ada di file terlampir onelotus-mobile-ui-enhancement.md — ikuti itu
sebagai sumber kebenaran, terutama §2 (design tokens), §4 (komponen),
§12 (popup & pesan error), dan Lampiran A (katalog layar dengan ID).

Buat di Claude Design sebagai canvas berisi artboard ponsel 390×844.
Satu artboard = satu layar, diberi label "ID — Nama layar" (mis. "TR-04 — Rekam sesi").
Kelompokkan artboard per peran dalam baris/section:
Umum (UM), Terapis (TR), Kasir (KS), Owner (OW), Pasien (PS), Web (WB),
State & Feedback.

Aturan visual (wajib):
- Warna: bg #F3F8FB, surface #FFFFFF, surfaceAlt #EAF3F9, line #E1EBF2,
  fg #0D2233, muted #62788A, brand #0284C7, brandDeep #0C4A6E,
  brandSoft #E0F2FE, gold #C27006 (hemat, maks 1 per layar, hanya untuk
  pendapatan/poin/upsell), ok #15803D/#DCF3E4, warn #A85207/#FDEED6,
  crit #B91C1C/#FDE6E6.
- Font Plus Jakarta Sans; angka, jam, nomor pasien pakai JetBrains Mono tabular.
- Ukuran: title 20, heading 16, body 14 (minimum untuk teks yang dibaca),
  caption 12. Target sentuh ≥ 48. Padding layar 16, radius kartu 16,
  tombol 12, chip pill.
- Kartu pakai border, bukan bayangan. Status selalu teks + warna.
- Status bar iOS di atas, home indicator di bawah. Tab bar sesuai peran (§3).
- Bahasa Indonesia; staf disapa "kamu", pasien "Anda".
- Data contoh realistis Indonesia: pasien Rina Setiawati (#0387, ankle kiri),
  Andi Pratama (#0412, LBP), Budi Hartono (home visit, Sukun),
  Sari Wulandari (pasien baru); terapis Dimas, Fajar, Laras;
  Klinik Pusat Malang; tanggal Selasa 6 Okt 2026.
  Harga contoh: Adjustment Therapy Rp250.000, masase cedera ringan 1 titik
  Rp150.000, tambahan cedera Rp100.000, diskon member 10%.

Prototipe dipakai untuk dua hal: presentasi ke mitra (harus rapi & meyakinkan)
dan acuan developer (harus menunjukkan state & aturan). Jangan konfirmasi dulu —
siapkan fondasi canvas lalu tunggu prompt batch berikutnya.
```

---

## Prompt 1 — Umum (UM-01 s/d UM-15)

```
Buat artboard untuk semua layar Umum di Lampiran A.3: UM-01 Splash,
UM-02 Perbarui aplikasi, UM-03 Pemeliharaan, UM-04 Login (tampilkan juga
varian terkunci setelah 5× gagal), UM-05 Login pertama (4 langkah boleh jadi
satu artboard dengan progress atau 2 artboard), UM-06 Lupa password,
UM-07 Kunci aplikasi (PIN), UM-08 Pilih cabang & peran, UM-09 Pusat notifikasi,
UM-10 Pencarian global (dengan hasil), UM-11 Akun, UM-12 Ubah password & PIN,
UM-13 Pengaturan notifikasi, UM-14 Status sinkron (ada 1 item gagal),
UM-15 Bantuan & kebijakan. Ikuti input, validasi, dan aturan tiap ID.
```

## Prompt 2 — Terapis (TR-01 s/d TR-14)

```
Buat artboard untuk semua layar Terapis di Lampiran A.4 (TR-01 sampai TR-14)
dengan tab bar terapis: Jadwal · Pasien · + · Riwayat · Akun.
TR-04 Rekam sesi adalah layar prioritas: tampilkan header pasien + timer,
banner peringatan medis, BodyMap (area ditangani & area penenang),
PainScale 7→3, keluhan, penyebab, lama cedera, analisa, TreatmentChips,
kesimpulan, lampiran, item tagihan tambahan, tombol melekat
"Simpan & kirim ringkasan ke pasien". Boleh dua artboard (atas & bawah scroll).
TR-09 Home visit sertakan status check-in; TR-10 tagih di lokasi pakai QRIS.
```

## Prompt 3 — Kasir / front desk (KS-01 s/d KS-18)

```
Buat artboard untuk semua layar Kasir di Lampiran A.5 (KS-01 sampai KS-18)
dengan tab bar kasir: Antrian · Pasien · + · Kasir · Akun.
KS-10 Pembayaran tampilkan 3 artboard: Tunai (CashCalculator + kembalian),
QRIS (QrisPanel dengan hitung mundur), Pembayaran gabungan (paket + tunai).
KS-11 tampilkan layar sukses + pratinjau struk sesuai §6.4.5.
KS-14 refund tampilkan ringkasan dampak (kuota, poin, komisi).
```

## Prompt 4 — Owner (OW-01 s/d OW-20)

```
Buat artboard untuk semua layar Owner di Lampiran A.6 (OW-01 sampai OW-20)
dengan tab bar owner: Ringkasan · Jadwal · Pasien · Laporan · Akun.
OW-01 dashboard: KpiTile omzet Rp38,4 jt +12%, grafik mingguan berlabel angka,
64% pasien kembali, 81% slot terisi, sesi per terapis (Dimas 92, Fajar 78,
Laras 64), ActionAlert. OW-02 tampilan kolom per terapis.
Layar kelola (OW-08 s/d OW-17) cukup tampilan daftar + form edit dalam
satu artboard bila muat.
```

## Prompt 5 — Pasien (PS-01 s/d PS-20)

```
Buat artboard untuk semua layar Aplikasi Pasien di Lampiran A.7
(PS-01 sampai PS-20) dengan tab bar: Beranda · Latihan · Booking · Profil.
Nada lebih hangat & menenangkan, sapaan "Anda". PS-05 Beranda: progres
pemulihan ankle 72%, latihan hari ini, sesi berikutnya Kam 8 Okt 16.00,
240 poin Lotus. PS-08 Booking tampilkan langkah pilih slot (SlotPicker,
slot penuh berlabel "Penuh").
```

## Prompt 6 — Web pendukung (WB-01 s/d WB-03)

```
Buat artboard untuk Lampiran A.8: WB-01 form intake via QR (web mobile,
semua field termasuk TB/BB numerik & persetujuan data, plus layar
"Terima kasih" dengan nomor antrian), WB-02 halaman status pembayaran
(berhasil / menunggu / gagal), WB-03 form booking website.
```

## Prompt 7 — State & feedback

```
Buat section "State & Feedback" sebagai acuan developer, berdasarkan §12:
- 4 state untuk satu layar contoh (TR-01): isi, kosong, loading (skeleton),
  error.
- Semua jenis feedback §12.1–12.2: toast sukses/info/error, banner offline &
  peringatan, bottom sheet (sync gagal, duplicate_patient, edit_conflict),
  dialog konfirmasi (arsip pasien, batalkan transaksi, keluar tanpa simpan,
  kirim WA massal, logout dengan data belum sinkron), inline field error,
  layar error penuh (auth_expired).
- SyncIndicator 4 status, StatusTag semua status sesi, PaymentStatusBadge
  semua status pembayaran.
Pakai pesan persis dari katalog §12.4–12.6.
```

## Prompt 8 — Ikon, ilustrasi, animasi & gaya v2

```
Terapkan aset & gaya Lampiran D (D.0–D.5) spesifikasi:
1) Ikon: Phosphor Icons saja. regular = default, fill = tab aktif/opsi terpilih,
   duotone = status berwarna. Lembar 72 ikon D.1 berlabel nama One Lotus + Phosphor.
2) Ilustrasi: 20 ilustrasi unDraw D.2, aksen #0277B5, figur #1E3A4F, latar #E8F0F6.
   Pasang di PS-01, UM-02, UM-03, KS-11, ST-01, ST-03, ST-15, WB-01 dan state kosong lain.
3) Animasi: storyboard 28 animasi D.3 (12 khusus One Lotus + 16 useAnimations,
   atribusi CC BY di halaman Lisensi).
4) Gaya v2 (D.5): latar #F2F5F8, kartu putih tanpa garis radius 20 + bayangan lembut,
   header hero #0B3B5C di 4 beranda, tombol 52dp radius 16, tab aktif = pil #E3F2FC.
```

---

## Prompt R — Revisi

```
Revisi artboard [ID — Nama layar]: [apa yang diubah].
Pertahankan token, komponen, dan data contoh yang sama dengan layar lain.
Jika perubahan menyentuh komponen bersama (mis. SessionCard, MoneyRow),
terapkan juga di semua artboard yang memakainya dan sebutkan mana saja.
```

## Prompt C — Cek kelengkapan

```
Bandingkan canvas dengan Lampiran A di spesifikasi. Buat daftar ID layar yang
belum ada, dan layar yang belum memenuhi input/validasi/aturan di katalog.
Lalu lengkapi yang kurang.
```

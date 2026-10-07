# One Lotus Mobile — Spesifikasi Enhancement UI

> Dokumen kerja untuk tim desain & developer Flutter.
> Turunan dari proposal **One Lotus Mobile** (Oktober 2026). Mockup di proposal adalah titik awal; dokumen ini menjadikannya spesifikasi yang siap dibangun dan diuji.

- **Platform:** Flutter (Android & iOS, satu kode)
- **Aplikasi:** (1) Aplikasi Staf — terapis, kasir/front desk, owner (menu menyesuaikan peran) · (2) Aplikasi Pasien
- **Backend:** One Lotus API (Laravel terbaru + Sanctum)
- **Status:** Draft v1 — untuk divalidasi di workshop kebutuhan (Minggu 1)
- **Cakupan:** 90 layar (UM 15 · TR 14 · KS 18 · OW 20 · PS 20 · WB 3) — daftar & requirement lengkap di Lampiran A, pengecekan kelengkapan di Lampiran B, prompt Claude Design di Lampiran C, aset 72 ikon (Phosphor, 3 bobot) · 20 ilustrasi (unDraw) · 28 animasi Lottie (12 khusus + 16 useAnimations) di Lampiran D

---

## 1. Tujuan enhancement

| # | Masalah di mockup/alur saat ini | Target |
|---|---|---|
| 1 | Rekam sesi masih berpotensi lama diisi | Sesi rutin tercatat **≤ 60 detik**, ≤ 8 ketukan |
| 2 | Status offline/sinkron hanya teks kecil | Status sinkron selalu jelas, tidak ada data "hilang diam-diam" |
| 3 | Peran berbeda tapi navigasi sama | Tab bar & beranda berbeda per peran |
| 4 | Ukuran teks mockup 9–11px (terlalu kecil di HP asli) | Minimal **14sp** untuk body, target sentuh **≥ 48dp** |
| 5 | Belum ada state kosong, loading, error | Setiap layar punya 4 state: isi, kosong, loading, error |
| 6 | Data sensitif (telepon, rontgen) tampil sama ke semua | Tampilan data mengikuti hak akses per peran (selaras Fase 0 & UU PDP) |

**Prinsip:** cepat di tangan terapis yang sedang bekerja · jelas untuk kasir di jam sibuk · ringkas untuk owner · menenangkan untuk pasien.

---

## 2. Design tokens

Ambil dari palet proposal (brand "lotus" sky blue + aksen emas hemat). Simpan sebagai `ThemeExtension` agar mudah diganti.

### 2.1 Warna — tema terang (default aplikasi)

| Token | Hex | Pemakaian |
|---|---|---|
| `bg` | `#F3F8FB` | Latar layar |
| `surface` | `#FFFFFF` | Kartu, sheet |
| `surfaceAlt` | `#EAF3F9` | Chip non-aktif, field |
| `line` | `#E1EBF2` | Border, divider |
| `fg` | `#0D2233` | Teks utama |
| `muted` | `#62788A` | Teks sekunder |
| `brand` | `#0284C7` | Aksi utama, tab aktif |
| `brandDeep` | `#0C4A6E` | Teks di atas `brandSoft`, header |
| `brandSoft` | `#E0F2FE` | Latar tag, highlight sesi aktif |
| `gold` | `#C27006` | Fitur pendapatan, poin, upsell paket (hemat, maks 1 per layar) |
| `ok` / `okSoft` | `#15803D` / `#DCF3E4` | Selesai, tersinkron, lunas |
| `warn` / `warnSoft` | `#A85207` / `#FDEED6` | Home visit, menunggu, paket hampir habis |
| `crit` / `critSoft` | `#B91C1C` / `#FDE6E6` | Gagal sinkron, peringatan medis |

### 2.2 Warna — tema gelap (opsional, Fase 3)

`bg #08151F` · `surface #0F2130` · `line #22394C` · `fg #E5F0F8` · `muted #9DB3C4` · `brand #38BDF8` · `gold #F2A93B` · `ok #4ADE80` · `crit #F87171`.
Ikuti setting sistem; sediakan toggle manual di Akun.

### 2.3 Tipografi

Font: **Plus Jakarta Sans** (display & body), **JetBrains Mono** (nomor pasien, jam, nominal opsional).

| Style | Ukuran / tebal | Contoh |
|---|---|---|
| `display` | 28sp / 800 | Omzet di dashboard owner |
| `title` | 20sp / 800 | Judul layar ("Rekam sesi") |
| `heading` | 16sp / 700 | Judul kartu |
| `body` | 14sp / 500 | Isi utama — **minimum untuk teks yang harus dibaca** |
| `caption` | 12sp / 500 | Label, metadata |
| `mono` | 13sp / 500, tabular | `#0412`, `09.00`, `Rp450.000` |

Semua angka memakai **tabular figures**. Uji dengan text scale 130% — tidak boleh ada teks terpotong.

### 2.4 Spasi, radius, elevasi

- Grid 4dp. Padding layar 16dp, jarak antar kartu 12dp, padding kartu 12–16dp.
- Radius: kartu 16dp · tombol 12dp · chip/tag pill 999 · bottom sheet 24dp (atas).
- Elevasi minimal: kartu pakai border `line`, bukan bayangan. Bayangan hanya untuk FAB & sheet.
- Target sentuh **≥ 48×48dp**, jarak antar target ≥ 8dp.

### 2.5 Ikon, ilustrasi & gerak

- **Ikon:** satu pustaka saja — Phosphor Icons (MIT), 24dp. Bobot *regular* untuk default, *fill* untuk tab aktif/terpilih, *duotone* untuk ikon status berwarna. Inventori & pemetaan nama: Lampiran D.1.
- **Ilustrasi:** unDraw, diwarnai ulang ke palet brand (aksen #0277B5, figur #1E3A4F, latar #E8F0F6), dipakai di onboarding, state kosong, sukses, pembaruan, dan error. Inventori: Lampiran D.2.
- **Animasi:** Lottie — animasi khusus One Lotus untuk momen bermerek (splash, sukses bayar, check-in, QRIS, poin) + ikon animasi useAnimations untuk umpan balik kecil (loading, centang, alert, lonceng); mikro-interaksi dikodekan di Flutter. Durasi umum 150–250ms, kurva `easeOutCubic`. Hormati "kurangi gerakan" di setting sistem. Inventori: Lampiran D.3.
- Haptic ringan saat: simpan sesi, konfirmasi bayar, check-in berhasil.

---

## 3. Navigasi per peran

Satu Aplikasi Staf, tab bar menyesuaikan peran setelah login (role dari API).

| Peran | Tab bar (kiri → kanan) | Aksi tengah (FAB) |
|---|---|---|
| **Terapis** | Jadwal · Pasien · **+** · Riwayat · Akun | Rekam sesi untuk sesi yang sedang berjalan |
| **Kasir / front desk** | Antrian · Pasien · **+** · Kasir · Akun | Pasien baru / tampilkan QR intake |
| **Owner** | Ringkasan · Jadwal · Pasien · Laporan · Akun | — (tanpa FAB) |
| **Aplikasi Pasien** | Beranda · Latihan · Booking · Profil | — |

Catatan:
- Staf dengan banyak peran (mis. owner yang juga terapis) mendapat **pengalih peran** di header Akun, bukan tab tambahan.
- Label tab selalu tampil (bukan ikon saja). Tab aktif: ikon terisi + warna `brand`.
- FAB kontekstual: bila tidak ada sesi berjalan, FAB terapis membuka pemilih pasien.

---

## 4. Komponen inti

| Komponen | Spesifikasi kunci |
|---|---|
| **AppHeader** | Konteks kecil (tanggal · cabang, `caption muted`) + judul (`title`). Indikator sinkron di kanan. |
| **SyncIndicator** | 4 status: `Tersinkron` (ok) · `Menyimpan…` (muted, spinner) · `Offline — n catatan menunggu` (warn) · `Gagal sinkron` (crit, ketuk untuk detail). Selalu terlihat di layar yang mengedit data. |
| **SessionCard** | Jam (mono) · nama pasien · layanan · ruang/lokasi · status tag. Sesi berjalan: border `brand` + ring `brandSoft` + tombol "Buka rekam sesi". |
| **StatusTag** | Mengikuti siklus sesi (§6.2): `Menunggu konfirmasi` muted · `Dijadwalkan` brand outline · `Hadir` brand · `Berjalan` brand terisi · `Selesai` ok · `Belum bayar` warn · `Lunas` ok · `Tidak datang` crit · `Dibatalkan` muted coret. Tag tambahan: `Home visit` warn · `Pasien baru` brand outline. Selalu teks + warna (jangan warna saja). |
| **PainScale** | 0–10, 11 segmen ≥ 28dp lebar. Dua penanda: sebelum (muted) & sesudah (brand). Angka besar di atas: `7 → 3`. Geser atau ketuk. |
| **BodyMap** | Siluet depan/belakang, ketuk area → chip area muncul di bawah. Zoom area tangan/kaki. Simpan sebagai kode area, bukan teks bebas. |
| **TreatmentChips** | Template per layanan (Adjustment, Infrared, Stretching, Kinesio tape, Akupuntur…). Multi-select, chip aktif terisi `brand`. Urutan menurut frekuensi pemakaian terapis. |
| **AttachmentRow** | Foto (kamera/galeri), rontgen, catatan suara. Thumbnail + progres unggah per file. Rontgen berlabel "Akses terbatas". |
| **MoneyRow** | Label kiri, nominal kanan (tabular). Diskon dengan tanda minus & warna `ok`. Total `heading`, garis atas. |
| **PaymentMethodSelector** | QRIS · Tunai · Transfer/VA · Pakai paket · Poin — daftar pilihan dengan ikon. "Pakai paket" hanya muncul bila ada kuota; "Poin" bila saldo cukup. Mendukung **pembayaran gabungan** (mis. paket + tunai untuk biaya tambahan): sisa tagihan tampil di atas setelah tiap metode. |
| **PaymentStatusBadge** | Mengikuti status pembayaran (§6.4.1); dipakai di tagihan, riwayat transaksi, profil pasien, dan app pasien. |
| **CashCalculator** | Input uang diterima dengan tombol cepat (pas, 50rb, 100rb, 200rb), kembalian otomatis besar di bawah. |
| **QrisPanel** | QR besar + nominal + hitung mundur kedaluwarsa + status langsung ("Menunggu" → "Lunas"); tombol "Buat QR baru" & "Ganti metode". Kecerahan layar dinaikkan otomatis. |
| **UpsellCard** | Satu-satunya pemakaian `gold` di layar kasir. Bisa ditutup, tidak menghalangi tombol bayar. |
| **KpiTile** | Nilai `display`, label `caption`, delta (+12%) dengan arah & warna. |
| **ActionAlert** | Peringatan yang bisa ditindaklanjuti (mis. "14 pasien belum kembali >30 hari" → "Kirim pengingat"). |
| **EmptyState** | Ilustrasi kecil + 1 kalimat + 1 aksi. Contoh: "Belum ada sesi hari ini" → "Lihat jadwal minggu ini". |
| **SearchBar** | Cari pasien berdasarkan nama, nomor (`#0412`), atau 4 digit akhir HP (peran berwenang). Hasil muncul sejak 2 huruf, debounce 300ms, riwayat pencarian terakhir. |
| **FilterChips & Sort** | Chip filter di bawah judul daftar (status, terapis, cabang, periode); jumlah filter aktif tampil di badge; tombol "Reset". |
| **ListPaging** | Infinite scroll 20 item per halaman + indikator "memuat lagi" di bawah. Tidak ada daftar yang memuat semua data sekaligus (menjawab temuan dashboard lambat). |
| **FormField** | Label di atas (bukan placeholder saja), penanda wajib `*`, helper text, inline error (§12). Keyboard sesuai tipe (angka untuk TB/BB, telepon untuk HP). |
| **DateTimePicker & SlotPicker** | Strip tanggal + grid slot jam; slot penuh dinonaktifkan dengan label "Penuh", bukan disembunyikan. Zona waktu WIB. |
| **NotificationItem** | Ikon jenis, judul, waktu relatif ("5 mnt lalu"), titik belum dibaca; ketuk → deep link ke layar terkait. |
| **ConsentCheckbox** | Teks persetujuan yang bisa dibuka penuh, wajib dicentang aktif, waktu persetujuan tersimpan. |
| **Skeleton** | Bentuk kartu abu `surfaceAlt`, shimmer halus, maks 1,5 dtk sebelum pesan "Masih memuat…". |

---

## 5. Spesifikasi per layar

> Bagian ini menjelaskan isi & perilaku utama. Requirement lengkap setiap layar (ID, pintu masuk, data, input & validasi, aksi, aturan, edge case) ada di **Lampiran A — Katalog layar**.

### 5.1 Terapis — Beranda / Jadwal hari ini

- Sapaan + ringkasan 3 angka: sesi hari ini · home visit · pasien baru (ketuk → filter daftar).
- Daftar **SessionCard** berurutan waktu; sesi berjalan otomatis di-scroll ke atas layar.
- Tarik untuk refresh; pilih tanggal dengan strip 7 hari horizontal.
- **Enhancement:** tampilkan "berikutnya dalam 25 mnt" di kartu sesi selanjutnya; sesi home visit menampilkan jarak & estimasi waktu.
- State kosong: "Tidak ada sesi hari ini".

### 5.2 Terapis — Rekam sesi (layar prioritas)

Urutan dari atas: identitas pasien (nama · #nomor · layanan) → **BodyMap** → **PainScale** → **TreatmentChips** → catatan (opsional, teks/suara) → lampiran → tombol simpan.

- **Prefill** dari sesi sebelumnya: area, treatment, dan skala nyeri "sebelum" = nilai "sesudah" sesi lalu. Terapis cukup mengoreksi.
- **Autosave lokal** setiap perubahan; tombol tidak pernah "hilang data".
- Tombol utama melekat di bawah: **"Simpan & kirim ringkasan ke pasien"**; aksi sekunder: "Simpan saja".
- Peringatan medis dari riwayat (mis. "hindari tekanan kuat L4–L5") tampil sebagai banner `critSoft` di atas BodyMap.
- Validasi lunak: area & minimal 1 treatment wajib; sisanya opsional.
- Ukur: median waktu dari buka layar → simpan.

### 5.3 Terapis — Detail pasien & riwayat

- Header: avatar inisial, nama, umur · gender, aktivitas (hobi), TB/BB.
- Kartu cedera utama + **grafik tren nyeri** per sesi (garis, label sumbu jelas, angka awal & akhir).
- Kartu paket aktif: nama paket, sisa kuota (warn bila ≤ 1).
- Riwayat sesi: tanggal · terapis · ringkasan 1 baris; ketuk untuk detail.
- Data lama dari sistem Laravel (9 kolom teks) ditampilkan apa adanya di bagian "Catatan lama" — tidak dipaksa masuk format baru.
- Nomor telepon hanya tampil untuk peran berwenang; lainnya melihat tombol "Hubungi via klinik".

### 5.4 Terapis lapangan — Home visit

- Alamat lengkap + patokan, jarak & waktu tempuh, tombol "Buka Maps" (deep link Google Maps/Waze).
- Catatan medis penting di kartu terpisah.
- Checklist alat (ketuk untuk centang, tersimpan lokal).
- **Check-in di lokasi:** tombol aktif bila dalam radius (mis. 200 m); di luar radius → konfirmasi dengan alasan. Tampilkan waktu check-in & check-out.
- Status izin lokasi ditangani jelas: bila ditolak, jelaskan kegunaannya + tombol ke setting.
- **Tagih di lokasi** setelah sesi selesai: tagihan ringkas (layanan + ongkos transport otomatis dari jarak) → QRIS / tunai / pakai paket / kirim link bayar (§6.4.2). Tunai masuk "Kas dibawa".

### 5.5 Kasir — Tagihan & pembayaran

- Header: nama pasien, terapis, layanan dari sesi (otomatis dari rekam sesi).
- **MoneyRow** dari pricelist (per titik, tambahan cedera, diskon member). Kasir bisa menambah item dari pencarian layanan.
- **PaymentMethodSelector**; QRIS menampilkan kode besar layar penuh + status menunggu → lunas otomatis.
- **UpsellCard** paket bila pasien membayar per sesi berulang.
- Info "Komisi terapis tercatat otomatis" kecil di bawah total.
- Tombol: **"Konfirmasi & kirim struk WhatsApp"**. Setelah sukses: layar konfirmasi dengan opsi cetak/kirim ulang.
- Tutup kas harian: lihat §5.11 & KS-17.

### 5.6 Kasir — Intake pasien baru (QR)

- Layar QR besar untuk discan pasien di meja; daftar "baru masuk" real-time di bawah.
- Data masuk → kasir verifikasi (TB/BB numerik tervalidasi) → buat nomor pasien → jadwalkan.
- Deteksi kemungkinan pasien ganda (nama + tanggal lahir mirip) sebelum membuat nomor baru.

### 5.7 Owner — Ringkasan bisnis

- Filter periode & cabang di header (default: bulan ini, semua cabang).
- **KpiTile** omzet + delta; grafik batang mingguan.
- Dua KPI pendukung: % pasien kembali · % slot terapis terisi.
- Sesi per terapis: bar horizontal berlabel angka.
- **ActionAlert** pasien yang belum kembali → kirim pengingat WhatsApp (konfirmasi jumlah penerima dulu).
- Semua grafik punya angka terlihat (bukan hanya bentuk) dan bisa diketuk untuk detail.

### 5.8 Aplikasi pasien — Beranda

- Sapaan + **progres pemulihan** (lingkar %, kalimat "Nyeri turun dari 8 ke 2 dalam 6 sesi").
- Latihan hari ini dari terapis: daftar dengan centang + video.
- Sesi berikutnya: tanggal, jam, cabang, sisa paket; aksi "Ubah jadwal".
- Poin Lotus (aksen `gold`) + nilai rupiah.
- Tombol **"Booking ulang"** utama.
- Bahasa ramah & awam (hindari istilah klinis tanpa penjelasan).

### 5.9 Umum (semua peran staf) — masuk, akun, notifikasi

| Layar | Isi & perilaku |
|---|---|
| **Splash & cek versi** | Logo, cek token tersimpan. Versi app di bawah minimum → layar "Perbarui aplikasi" (wajib) atau banner (opsional). Mode pemeliharaan → layar info + perkiraan selesai. |
| **Login** | Username + password (selaras tabel `users` yang ada), tampilkan/sembunyikan password, "Ingat perangkat ini". Gagal 5× → kunci 5 menit dengan pesan jelas. |
| **Login pertama** | Wajib ganti password sementara → atur PIN/biometrik → izin notifikasi (dengan penjelasan manfaat). |
| **Lupa password** | Tidak reset sendiri; tombol "Minta reset ke admin" yang mengirim permintaan ke owner/admin. |
| **Pilih cabang** | Muncul bila akun terdaftar di >1 cabang; cabang aktif tampil di AppHeader dan bisa diganti dari Akun. |
| **Pusat notifikasi** | Ikon lonceng di AppHeader dengan badge. Tab "Semua / Belum dibaca", tandai semua dibaca. Jenis: sesi baru/berubah, booking website masuk, pasien hadir, pembayaran, sinkron gagal, pengumuman. |
| **Pencarian global** | Dari ikon cari di AppHeader: pasien (nama/nomor), lalu sesi hari ini. Hasil dibatasi oleh hak akses peran. |
| **Akun** | Profil (nama, foto, peran, cabang), pengalih peran, ubah password & PIN, pengaturan notifikasi per jenis, tema, ukuran teks (ikut sistem), status sinkron & "Kirim log ke tim", versi app, bantuan, logout (§12.5). |

### 5.10 Terapis — layar pelengkap

| Layar | Isi & perilaku |
|---|---|
| **Jadwal minggu & ketersediaan** | Tampilan minggu; terapis menandai jam tidak tersedia / ajukan cuti → menunggu persetujuan owner (status tampil). |
| **Mulai & akhiri sesi** | Dari SessionCard: "Mulai sesi" (status → Berjalan, timer berjalan di header) → rekam sesi → "Selesai" (status → Selesai, otomatis masuk antrian kasir). |
| **Tandai tidak datang / ubah jadwal** | Dari SessionCard (geser atau menu ⋯): Tidak datang (wajib alasan) · Minta pindah jadwal → diteruskan ke front desk. |
| **Tab Riwayat** | Sesi yang sudah ditangani, filter periode; tiap item → detail sesi. Badge "Belum lengkap" untuk sesi tanpa catatan. |
| **Detail sesi** | Tampilan baca-saja hasil rekam sesi. Edit diizinkan sampai batas waktu (mis. 24 jam) oleh pembuat; setelahnya hanya addendum. Riwayat perubahan terlihat. |
| **Pasien saya** | Daftar pasien yang pernah ditangani, urut kunjungan terakhir, penanda "belum kembali >30 hari". |
| **Komisi saya** | Ringkasan periode berjalan: jumlah sesi, home visit, estimasi komisi, rincian per sesi. Angka bertanda "estimasi" sampai owner menyetujui. |
| **Kirim program latihan** (Fase 3) | Dari detail pasien: pilih latihan dari pustaka (pencarian + kategori area tubuh), atur set/repetisi, pratinjau tampilan di app pasien, kirim. |

### 5.11 Kasir / front desk — layar pelengkap

| Layar | Isi & perilaku |
|---|---|
| **Antrian hari ini** (tab utama) | Kolom status: Dijadwalkan → Hadir → Berjalan → Selesai/Belum bayar. Tombol "Tandai hadir" saat pasien datang; tetapkan/ganti terapis & ruang. Walk-in: tombol "+ Sesi tanpa jadwal". |
| **Buat / ubah jadwal** | Cari/pilih pasien → layanan → cabang → terapis (atau "siapa saja") → SlotPicker → ruang / alamat home visit → ringkasan → simpan. Bentrok jadwal dicegah di SlotPicker, bukan setelah simpan. |
| **Booking masuk** | Dari website & aplikasi pasien: daftar "Menunggu konfirmasi" dengan aksi Terima · Usulkan jam lain · Tolak (wajib alasan, pasien diberi tahu). |
| **Daftar & pencarian pasien** | SearchBar + FilterChips + ListPaging. Item: nama, nomor, kunjungan terakhir, paket aktif. |
| **Tambah / edit data pasien** | Form per bagian (identitas · kontak · fisik · catatan). Nomor pasien otomatis, tidak bisa diedit staf biasa (menjawab temuan "edit ditolak bila nomor tidak diganti"). Persetujuan PDP (ConsentCheckbox) wajib untuk pasien baru. |
| **Jual paket / membership** | Pilih paket → harga & masa berlaku → metode bayar → kuota langsung aktif di profil pasien. |
| **Riwayat transaksi** | Daftar per hari, filter metode bayar; detail → kirim ulang struk · batalkan/refund (dialog §12.5, wajib alasan, perlu persetujuan owner di atas nominal tertentu). |
| **Tutup kas harian** | Ringkasan per metode (sistem vs. dihitung), input uang tunai fisik, selisih otomatis dengan warna, catatan, kirim ke owner. Setelah ditutup, transaksi hari itu terkunci. |
| **Pratinjau struk** | Tampilan struk sebelum dikirim WA / dicetak (printer Bluetooth opsional). |

### 5.12 Owner — layar pelengkap

| Layar | Isi & perilaku |
|---|---|
| **Tab Jadwal** | Semua terapis per hari (tampilan kolom per terapis), okupansi slot, bisa buat/ubah jadwal seperti kasir. |
| **Tab Laporan** | Omzet & transaksi · layanan terlaris · kinerja terapis · retensi pasien · home visit. Filter periode & cabang, ekspor PDF/Excel (dicatat di audit log, tanpa nomor telepon kecuali dipilih eksplisit). |
| **Persetujuan** | Satu daftar untuk: cuti terapis, pembatalan/refund, rekap komisi, permintaan reset password. Badge jumlah di tab Ringkasan. |
| **Rekap & persetujuan komisi** | Per terapis per periode, rincian bisa dibuka, setujui → status "Siap dibayar". |
| **Kelola staf** | Daftar akun (pengganti halaman `/user`), tambah/nonaktifkan (bukan hapus), atur peran & cabang, reset password. |
| **Kelola layanan & harga** | Pricelist per cabang: nama layanan, durasi, harga, biaya per titik, tambahan cedera, harga member. Perubahan berlaku untuk transaksi baru saja. |
| **Kelola paket & membership** | Isi paket, kuota, masa berlaku, harga. |
| **Aturan komisi** | Per layanan / per titik / per home visit, persen atau nominal, pratinjau contoh hitungan. |
| **Template** | Template treatment per layanan · area tubuh · pesan WhatsApp (pengingat H-1, follow-up, struk) dengan pratinjau & variabel `{nama}`, `{jam}`. |
| **Cabang** (Fase 3) | Data cabang, jam operasional, ruang, radius check-in. |
| **Audit log** | Siapa melihat/mengubah/mengekspor data pasien, filter per staf & tanggal, baca-saja. |

> Pengaturan berat (template, aturan komisi, audit log) boleh tetap di **panel admin web**; aplikasi cukup menampilkan ringkasan & persetujuan. Putuskan di workshop.

### 5.13 Aplikasi pasien — layar pelengkap

| Layar | Isi & perilaku |
|---|---|
| **Onboarding & masuk** | 2–3 layar perkenalan singkat → masuk dengan nomor HP + kode OTP WhatsApp. |
| **Hubungkan data lama** | Bila nomor HP cocok dengan pasien lama → konfirmasi nama & tanggal lahir → riwayat muncul. Tidak cocok → daftar baru (form intake yang sama dengan QR). |
| **Persetujuan data** | ConsentCheckbox kebijakan privasi & penggunaan data kesehatan, bisa dilihat ulang di Profil. |
| **Booking** | Layanan (dengan harga & durasi) → cabang / home visit (alamat + peta) → terapis (opsional) → SlotPicker → ringkasan (harga, potongan member/poin) → bayar DP bila diwajibkan (§6.4.2) → kirim. Status "Menunggu konfirmasi" sampai diterima front desk. |
| **Jadwal saya** | Mendatang & lalu. Ubah/batalkan sampai batas waktu (mis. H-1 pukul 18.00); setelahnya tombol "Hubungi klinik". |
| **Detail latihan** | Video, langkah, set/repetisi, tombol "Selesai hari ini", catatan untuk terapis ("terasa sakit di…"). |
| **Riwayat sesi** | Ringkasan versi pasien (area, treatment, saran) — tanpa catatan internal terapis. |
| **Paket & pembayaran** | Paket aktif, sisa kuota & masa berlaku, beli/perpanjang paket via gateway, tagihan Belum lunas dengan tombol "Bayar sekarang", riwayat pembayaran & refund, struk digital. |
| **Poin & referral** | Saldo poin, riwayat perolehan/penggunaan, kode referral + bagikan. |
| **Notifikasi & profil** | Pengingat jadwal, latihan, promo (bisa dimatikan per jenis). Profil: data diri, alamat home visit tersimpan, keluar, minta hapus akun. |

---

## 6. Alur end-to-end lintas peran

### 6.1 Perjalanan pasien (jalur utama)

| # | Langkah | Pasien | Kasir / front desk | Terapis | Owner | Status sesi |
|---|---|---|---|---|---|---|
| 1 | Booking | Booking di app / website | Notifikasi "booking masuk" → Terima | — | — | Menunggu konfirmasi → Dijadwalkan |
| 2 | Pengingat | WA H-1 + push | — | Jadwal muncul di Beranda | — | Dijadwalkan |
| 3 | Kedatangan | (Pasien baru: scan QR intake) | Verifikasi data → Tandai hadir | Notifikasi "pasien hadir" | — | Hadir |
| 4 | Sesi | — | — | Mulai sesi → Rekam sesi → Selesai | — | Berjalan → Selesai |
| 5 | Pembayaran | Terima struk WA | Tagihan otomatis → bayar / pakai paket | — | — | Belum bayar → Lunas |
| 6 | Tindak lanjut | Ringkasan sesi & latihan rumah | — | Kirim program latihan | — | — |
| 7 | Retensi | Follow-up H+3, pengingat bila >30 hari | — | — | ActionAlert pasien belum kembali | — |
| 8 | Akhir hari / bulan | — | Tutup kas | Cek komisi saya | Setujui komisi, lihat laporan | — |

### 6.2 Siklus status sesi

```
Menunggu konfirmasi ──Terima──▶ Dijadwalkan ──Tandai hadir──▶ Hadir ──Mulai──▶ Berjalan ──Selesai──▶ Selesai/Belum bayar ──Bayar──▶ Lunas
        │                           │                            │
      Tolak                   Batal / Pindah               Tidak datang
        ▼                           ▼                            ▼
    Dibatalkan              Dibatalkan / (jadwal baru)     Tidak datang
```

Setiap perpindahan status: siapa yang boleh melakukannya mengikuti §7, tercatat di audit log, dan memicu notifikasi ke peran terkait.

### 6.3 Alur pengecualian yang wajib punya layar

| Situasi | Penanganan UI |
|---|---|
| Walk-in tanpa booking | Antrian → "+ Sesi tanpa jadwal" → langsung Hadir |
| Pasien terlambat > 15 mnt | Banner di SessionCard terapis & kasir; pilihan: tunggu · pindah jadwal · tidak datang |
| Terapis berhalangan mendadak | Owner/kasir pindahkan sesi ke terapis lain secara massal; pasien diberi tahu |
| Home visit batal di lokasi | Terapis: "Batalkan di lokasi" + alasan + foto opsional; check-in tetap tercatat untuk ongkos transport |
| Paket habis di tengah program | Inline di tagihan + UpsellCard perpanjang paket |
| Pembayaran sebagian / utang | Status "Belum lunas" dengan sisa; muncul di riwayat transaksi & profil pasien (putuskan di workshop apakah diizinkan) — detail di §6.4 |
| Data pasien ganda | Bottom sheet `duplicate_patient` (§12.4); penggabungan data hanya oleh admin/owner |

### 6.4 Pembayaran end-to-end

#### 6.4.1 Siklus status pembayaran

```
Draft ──Terbitkan──▶ Belum bayar ──Pilih metode──▶ Menunggu pembayaran ──Berhasil──▶ Lunas ──▶ (Refund sebagian / Refund penuh)
                         │                               │
                    Bayar sebagian                 Gagal / Kedaluwarsa ──▶ kembali ke Belum bayar
                         ▼
                    Belum lunas (sisa Rp…) ──Lunasi──▶ Lunas

Draft / Belum bayar ──Batalkan (alasan)──▶ Dibatalkan
```

- **Draft**: tagihan terbentuk otomatis saat sesi "Selesai" dari layanan & item di rekam sesi. Kasir masih bisa ubah item.
- **Belum bayar**: item terkunci; perubahan harga hanya lewat diskon/penyesuaian yang tercatat.
- **Menunggu pembayaran**: hanya untuk QRIS, transfer/VA, dan link bayar. Tunai & paket langsung Lunas.
- Status hanya berubah ke Lunas dari **konfirmasi server** (webhook gateway / input kasir), bukan dari app pasien — mencegah "lunas palsu".

#### 6.4.2 Titik bayar & siapa yang menagih

| Titik bayar | Penagih | Layar | Metode |
|---|---|---|---|
| Di klinik setelah sesi | Kasir | Tagihan (§5.5) | Semua |
| Home visit di lokasi | **Terapis** | Tagihan versi ringkas di layar home visit | QRIS, tunai, pakai paket |
| Booking online (DP / bayar di muka, opsional) | Pasien | Ringkasan booking → bayar | QRIS, VA, e-wallet via gateway |
| Beli / perpanjang paket | Kasir atau pasien | Jual paket (§5.11) / Paket di app pasien | Semua (pasien: via gateway) |
| Pelunasan sisa tagihan | Pasien atau kasir | Link bayar WA / tagihan | Via gateway / semua |

#### 6.4.3 Alur per metode

| Metode | Langkah UI | Bukti & status |
|---|---|---|
| **Tunai** | Pilih Tunai → CashCalculator → Konfirmasi | Langsung Lunas, masuk kas kasir/terapis. Bisa dicatat offline (antre sinkron, tanda "belum tersinkron" di riwayat). |
| **QRIS** | Pilih QRIS → QrisPanel → app mendengar status (push/websocket, fallback polling 5 dtk) → Lunas otomatis | Butuh koneksi. Bila app ditutup/terputus, status dicek ulang saat dibuka; transaksi tidak bisa ditagih ulang selama "Menunggu" (`payment_pending_unknown`). |
| **Transfer / VA** | Disarankan VA dari gateway (cocok otomatis). Transfer manual: input bank & nominal + foto bukti → kasir/owner verifikasi | VA: otomatis Lunas. Manual: status "Menunggu verifikasi" sampai disetujui. |
| **Pakai paket** | Pilih paket aktif → tampil sisa kuota sebelum/sesudah → Konfirmasi | Kuota berkurang 1; biaya di luar paket (tambahan titik/cedera, transport) jadi sisa tagihan untuk metode lain. |
| **Poin Lotus** | Geser jumlah poin yang dipakai (maks sesuai aturan) → nilai rupiah langsung terlihat | Poin terpotong saat Lunas; dikembalikan bila dibatalkan/refund. |
| **Link bayar (WA)** | Kasir/terapis kirim link → pasien buka halaman bayar gateway | Status kembali ke app staf otomatis; pasien dapat struk. |

#### 6.4.4 Diskon, voucher, dan penyesuaian

- Sumber potongan: harga member (otomatis) · voucher/kode promo · diskon manual · poin.
- Diskon manual wajib alasan; di atas batas tertentu perlu **persetujuan owner** (notifikasi → setujui dari Persetujuan, tagihan menunggu).
- Urutan hitung tampil transparan di MoneyRow: subtotal → member → voucher → manual → poin → total.

#### 6.4.5 Setelah bayar

| Untuk | Yang terjadi | Layar |
|---|---|---|
| Pasien | Struk WA + push; struk tersimpan di app pasien | Paket & pembayaran (§5.13) |
| Kasir / terapis | Layar sukses: nominal, metode, kembalian, aksi Kirim ulang · Cetak · Selesai | Konfirmasi pembayaran |
| Terapis | Komisi sesi tercatat (estimasi) | Komisi saya |
| Paket & poin | Kuota berkurang / poin bertambah sesuai aturan | Profil pasien |
| Owner | Masuk omzet & laporan | Ringkasan bisnis |

**Isi struk:** logo & alamat cabang, nomor struk, tanggal & jam, nama pasien & nomor, terapis, item + harga, potongan, total, metode bayar (+ ref gateway), sisa kuota paket, poin didapat, nama kasir/terapis penagih. Tanpa catatan medis.

#### 6.4.6 Pembatalan & refund

| Kasus | Siapa | Dampak otomatis |
|---|---|---|
| Batal sebelum bayar | Kasir | Tagihan Dibatalkan, sesi tetap tercatat |
| Refund penuh / sebagian | Kasir ajukan → owner setujui (di atas batas) | Kuota paket & poin dikembalikan proporsional, komisi terapis disesuaikan, laporan omzet terkoreksi |
| Refund QRIS/VA | Owner | Dikembalikan lewat gateway bila didukung; bila tidak, refund tunai/transfer manual dicatat dengan bukti |
| Setelah tutup kas | Hanya owner | Dicatat sebagai koreksi di hari berjalan, bukan mengubah hari yang sudah ditutup |

Layar refund: pilih item/nominal → alasan (pilihan + catatan) → metode pengembalian → ringkasan dampak (kuota, poin, komisi) → dialog konfirmasi §12.5.

#### 6.4.7 Kas & rekonsiliasi

- **Kas terapis home visit**: tunai yang diterima terapis tampil sebagai "Kas dibawa" di Akun terapis → diserahkan ke kasir (kasir konfirmasi terima) sebelum tutup kas.
- **Tutup kas** (§5.11) memisahkan tunai fisik vs. non-tunai.
- **Rekonsiliasi gateway** (owner, Fase 2): transaksi sistem vs. laporan settlement gateway, potongan biaya (MDR) per transaksi, penanda selisih.
- **Piutang**: daftar tagihan Belum lunas di Laporan + ActionAlert "n tagihan belum lunas >7 hari" → kirim link bayar.

---

## 7. Matriks akses layar per peran

✓ penuh · 👁 lihat saja · ◐ terbatas · — tidak ada

| Layar / data | Terapis | Kasir | Owner | Pasien |
|---|---|---|---|---|
| Jadwal semua terapis | ◐ milik sendiri | ✓ | ✓ | — |
| Buat / ubah jadwal | ◐ ajukan pindah | ✓ | ✓ | ◐ booking sendiri |
| Data pasien — identitas | ✓ | ✓ | ✓ | ◐ diri sendiri |
| Nomor telepon & alamat | ◐ alamat saat home visit | ✓ | ✓ | ◐ diri sendiri |
| Rekam sesi & catatan medis | ✓ tulis | 👁 ringkasan | 👁 | ◐ ringkasan versi pasien |
| Foto rontgen | ✓ | — | 👁 | ◐ milik sendiri |
| Tagihan & pembayaran | ◐ hanya saat home visit | ✓ | ✓ | ◐ bayar & struk sendiri |
| Diskon manual di atas batas | — | ◐ ajukan | ✓ setujui | — |
| Verifikasi transfer manual | — | ✓ | ✓ | — |
| Rekonsiliasi gateway & piutang | — | 👁 piutang | ✓ | — |
| Batal / refund transaksi | — | ◐ ajukan | ✓ setujui | — |
| Tutup kas | — | ✓ | 👁 | — |
| Komisi | ◐ milik sendiri | — | ✓ | — |
| Laporan & ekspor | — | — | ✓ | — |
| Kelola staf, harga, paket, template | — | — | ✓ | — |
| Audit log | — | — | 👁 | — |

Menu dan tombol yang tidak diizinkan **disembunyikan**, bukan dinonaktifkan. API tetap menolak (403 → `forbidden` §12.4) bila diakses langsung.

---

## 8. Perilaku offline & sinkron

1. Semua tulis (rekam sesi, checklist, check-in) disimpan dulu ke database lokal (mis. Drift/Isar), lalu antre ke API.
2. Antrian dikirim otomatis saat koneksi kembali; retry dengan backoff.
3. **SyncIndicator** selalu menunjukkan jumlah item menunggu; ketuk → daftar item + status masing-masing.
4. Konflik (data diubah di dua perangkat): versi terbaru menang untuk field sederhana; untuk catatan medis, simpan keduanya dan minta terapis memilih.
5. Lampiran besar (foto rontgen) diunggah terpisah dengan progres; teks sesi tidak menunggu foto.
6. Kasir **tidak** mendukung pembayaran QRIS offline — tampilkan jelas "Butuh koneksi untuk QRIS", tunai tetap bisa dicatat.

---

## 9. Aksesibilitas & keterbacaan

- Kontras teks ≥ 4.5:1 (cek `muted` di atas `surfaceAlt`).
- Body minimum 14sp; uji text scale 100% / 130% / 160%.
- Status tidak boleh hanya dibedakan warna — selalu ada teks/ikon.
- Label semantik untuk screen reader di PainScale, BodyMap, dan grafik.
- Tombol utama di jangkauan jempol (bagian bawah layar).
- Bahasa Indonesia baku-santai, konsisten: "Simpan", bukan campur "Save".

---

## 10. Privasi di UI (selaras Fase 0 & UU PDP No. 27/2022)

- Nomor telepon, alamat, dan rontgen disamarkan untuk peran yang tidak berwenang.
- Layar berisi data medis: blokir screenshot di Android (`FLAG_SECURE`) untuk peran non-owner — opsional, putuskan di workshop.
- Kunci aplikasi dengan biometrik/PIN setelah tidak aktif 5 menit.
- Notifikasi push tidak memuat detail medis ("Ada sesi baru jam 10.30", bukan diagnosis).
- Export data hanya untuk peran admin/owner, dengan log.

---

## 11. Microcopy kunci

| Situasi | Teks |
|---|---|
| Simpan sesi sukses | "Sesi tersimpan. Ringkasan dikirim ke Andi." |
| Simpan offline | "Tersimpan di HP. Akan terkirim saat ada sinyal." |
| Gagal sinkron | "3 catatan belum terkirim. Ketuk untuk coba lagi." |
| Bayar QRIS menunggu | "Menunggu pembayaran… Layar akan berubah otomatis." |
| Check-in di luar radius | "Kamu ±600 m dari alamat. Tetap check-in? Tulis alasannya." |
| Paket hampir habis | "Sisa 1 sesi di paket ini." |
| Pasien — progres | "Nyeri turun dari 8 ke 2. Teruskan latihannya!" |

---

## 12. Sistem feedback: popup, toast & pesan error

Semua pesan ke pengguna lewat **satu layanan** (`AppFeedback`) — layar tidak boleh memanggil `showDialog`/`SnackBar` sendiri. Tujuannya: bentuk, warna, durasi, dan bahasa selalu sama di semua layar dan peran.

### 12.1 Pilih jenis feedback

Gunakan jenis paling ringan yang masih cukup. Urutan dari ringan ke berat:

| Jenis | Kapan dipakai | Menghalangi kerja? | Contoh |
|---|---|---|---|
| **Inline field error** | Isian form salah/kosong | Tidak | "Berat badan harus angka, mis. 58" |
| **Toast / Snackbar** | Konfirmasi aksi selesai, error ringan yang bisa diulang | Tidak | "Sesi tersimpan" · "Gagal memuat. Coba lagi" |
| **Banner** (di atas konten) | Kondisi yang berlangsung lama | Tidak | "Kamu sedang offline" · peringatan medis pasien |
| **Bottom sheet** | Pilihan lanjutan / detail error | Sebagian | Daftar item gagal sinkron · pilih versi saat konflik |
| **Dialog konfirmasi** | Aksi berisiko, tidak bisa dibatalkan, atau melibatkan uang | Ya | Hapus data, batalkan transaksi, kirim WA massal |
| **Layar error penuh** | Layar tidak bisa tampil sama sekali | Ya | Sesi login habis, server tidak terjangkau saat pertama buka |

**Aturan:**
- Dialog **hanya** untuk keputusan. Jangan pakai dialog untuk info "Berhasil" — itu toast.
- Maksimal **1 toast** tampil; toast baru menggantikan yang lama (antrian, tidak menumpuk).
- Maksimal **1 dialog** pada satu waktu. Jangan membuka dialog dari dalam dialog.
- Error saat sedang mengisi form **tidak boleh** menghapus isian.
- Error yang disebabkan offline tidak ditampilkan sebagai error — tampilkan SyncIndicator / banner offline (§8).

### 12.2 Anatomi & token

| Jenis | Bentuk | Warna | Durasi |
|---|---|---|---|
| Toast sukses | Pill di bawah, di atas tab bar/tombol melekat, ikon ✓ | `fg` latar gelap, ikon `ok` | 3 dtk |
| Toast info | sama | ikon `brand` | 3 dtk |
| Toast error | sama + tombol aksi ("Coba lagi") | ikon `crit` | 6 dtk, atau sampai ditutup bila ada aksi |
| Banner | Full width, radius 12, ikon kiri, aksi kanan | `warnSoft`/`warn` atau `critSoft`/`crit` | Sampai kondisi selesai |
| Dialog | Radius 24, judul `heading`, isi `body`, 1–2 tombol | Tombol berisiko: `crit` terisi | — |
| Inline error | Teks `caption` di bawah field, border field `crit` | `crit` | Hilang saat diperbaiki |

- Teks toast maks 2 baris; aksi maks 1 tombol.
- Ikon selalu menyertai warna (status tidak hanya dari warna).
- Haptic: sukses = ringan, error = notifikasi error, dialog berisiko = tidak ada.
- Screen reader membacakan toast & inline error (live region).

### 12.3 Pola penulisan pesan error

Setiap pesan error menjawab dua hal: **apa yang terjadi** + **apa yang bisa dilakukan**.

- ✅ "Foto rontgen gagal diunggah. Periksa sinyal lalu coba lagi."
- ❌ "Error 500: Internal Server Error"
- ❌ "Terjadi kesalahan."

Aturan bahasa:
- Bahasa Indonesia sehari-hari, sapaan "kamu" untuk staf, "Anda" untuk aplikasi pasien.
- Jangan menyalahkan pengguna ("Kamu salah input" → "Nomor HP belum lengkap").
- Tanpa istilah teknis, kode HTTP, atau nama tabel di teks utama.
- Error dari server menyertakan **kode referensi** kecil di bawah (mis. `Ref: OL-7F3A`) untuk dilaporkan ke tim — dicatat bersama log di server.
- Judul dialog berupa pertanyaan/aksi ("Batalkan transaksi ini?"), tombol berupa kata kerja ("Batalkan transaksi" / "Kembali"), bukan "Ya" / "Tidak".

### 12.4 Katalog pesan standar

Pemetaan error API & perangkat ke tampilan. Developer cukup melempar error ber-tipe; `AppFeedback` memilih tampilannya.

| Kode internal | Sumber | Jenis | Pesan |
|---|---|---|---|
| `network_offline` | Tidak ada koneksi | Banner warn | "Kamu sedang offline. Data tersimpan di HP." |
| `network_timeout` | Request > 15 dtk | Toast error + Coba lagi | "Koneksi lambat. Coba lagi." |
| `auth_expired` | 401 | Layar penuh → login | "Sesi login berakhir. Masuk lagi untuk melanjutkan." (data lokal tetap aman) |
| `forbidden` | 403 | Toast error | "Kamu tidak punya akses ke data ini." |
| `not_found` | 404 | Layar error di area konten | "Data tidak ditemukan. Mungkin sudah diarsipkan." |
| `validation` | 422 | Inline error per field | Pesan dari API per field, ditulis ulang sesuai §12.3 |
| `duplicate_patient` | 409 / deteksi ganda | Bottom sheet | "Pasien dengan nama & tanggal lahir ini sudah ada." → [Buka data lama] [Tetap buat baru] |
| `edit_conflict` | 409 versi | Bottom sheet | "Catatan ini juga diubah di perangkat lain." → pilih versi (§8 poin 4) |
| `rate_limited` | 429 | Toast info | "Terlalu banyak permintaan. Tunggu sebentar." |
| `server_error` | 5xx | Toast error + Ref | "Ada gangguan di server. Coba beberapa saat lagi." |
| `upload_failed` | Unggah lampiran | Inline di AttachmentRow + Coba lagi | "Gagal mengunggah. Ketuk untuk coba lagi." |
| `sync_failed` | Antrian sinkron | SyncIndicator crit → bottom sheet daftar | "3 catatan belum terkirim." |
| `perm_location` | GPS ditolak | Dialog penjelasan + [Buka pengaturan] | "Lokasi dipakai untuk check-in home visit." |
| `perm_camera` | Kamera ditolak | Dialog penjelasan + [Buka pengaturan] | "Kamera dipakai untuk foto rontgen & dokumen." |
| `checkin_out_of_range` | GPS di luar radius | Dialog + input alasan | "Kamu ±600 m dari alamat. Tetap check-in?" |
| `qris_expired` | Gateway | Inline di layar QRIS + [Buat QR baru] | "Kode QR kedaluwarsa." |
| `payment_failed` | Gateway | Dialog | "Pembayaran belum berhasil. Tagihan belum lunas." → [Coba lagi] [Ganti metode] |
| `payment_pending_unknown` | Status tidak jelas | Banner warn, cek otomatis | "Menunggu konfirmasi pembayaran. Jangan tagih ulang dulu." |
| `package_empty` | Kuota paket 0 | Inline di PaymentMethodSelector | "Kuota paket habis. Pilih metode lain atau beli paket baru." |
| `transfer_pending_verify` | Transfer manual | Banner info di tagihan | "Bukti transfer menunggu verifikasi." |
| `payment_double_guard` | Tagihan sudah Lunas / sedang menunggu | Dialog | "Tagihan ini sudah dibayar pukul 11.24. Jangan tagih ulang." → [Lihat struk] |
| `discount_needs_approval` | Diskon > batas | Banner warn di tagihan | "Diskon menunggu persetujuan owner." |
| `points_insufficient` | Poin kurang | Inline di selektor poin | "Poin belum cukup. Saldo: 240 poin." |
| `refund_not_supported` | Gateway tidak mendukung | Bottom sheet | "Refund QRIS tidak bisa otomatis. Catat pengembalian manual." |
| `wa_send_failed` | WhatsApp gateway | Toast error + Coba lagi | "Struk belum terkirim ke WhatsApp. Coba lagi." |
| `unknown` | Lainnya | Toast error + Ref | "Ada yang tidak beres. Coba lagi, atau laporkan dengan kode di bawah." |

### 12.5 Dialog konfirmasi wajib

Aksi berikut **selalu** lewat dialog konfirmasi (sekaligus menutup temuan "hapus cukup lewat satu link"):

| Aksi | Judul | Tombol utama | Catatan |
|---|---|---|---|
| Arsipkan pasien | "Arsipkan data Rina Setiawati?" | Arsipkan | Jelaskan: riwayat tetap tersimpan & bisa dipulihkan admin |
| Hapus catatan sesi | "Hapus catatan sesi 6 Okt?" | Hapus catatan | Hanya pembuat / admin, tercatat di audit log |
| Batalkan transaksi | "Batalkan transaksi Rp450.000?" | Batalkan transaksi | Wajib isi alasan |
| Keluar dari rekam sesi yang belum disimpan | "Simpan dulu catatan ini?" | Simpan | Opsi kedua: "Buang perubahan" (crit) |
| Kirim WhatsApp massal | "Kirim pengingat ke 14 pasien?" | Kirim ke 14 pasien | Tampilkan contoh pesan |
| Logout dengan data belum tersinkron | "Ada 3 catatan belum terkirim" | Tunggu sinkron | Opsi kedua: "Tetap keluar" (crit) — peringatkan data bisa hilang |

Tombol berisiko di kanan/bawah, warna `crit`; tombol aman ("Kembali") selalu ada. Ketuk di luar dialog = batal.

### 12.6 Pesan sukses standar

| Aksi | Toast |
|---|---|
| Simpan sesi | "Sesi tersimpan. Ringkasan dikirim ke {pasien}." |
| Pembayaran lunas | Layar konfirmasi (bukan toast) + "Struk terkirim ke WhatsApp" |
| Check-in | "Check-in tercatat 12.58." |
| Pasien baru dibuat | "Pasien #0413 dibuat." + aksi [Jadwalkan] |
| Data diperbarui | "Perubahan tersimpan." |

### 12.7 Catatan implementasi Flutter

```dart
// Satu pintu untuk semua feedback
abstract class AppFeedback {
  void success(String message, {FeedbackAction? action});
  void info(String message);
  void error(AppError error, {VoidCallback? retry}); // pilih tampilan dari katalog §12.4
  Future<bool> confirm(ConfirmSpec spec);             // dialog §12.5
  void banner(BannerSpec spec);
  void clearBanner(String id);
}

sealed class AppError {
  String get code;      // mis. 'network_timeout'
  String? get refId;    // dari header respons API
}
```

- Interceptor HTTP (Dio) memetakan status code & body API → `AppError`.
- API Laravel mengembalikan format error seragam: `{ "code": "...", "message": "...", "errors": {field: [...]}, "ref": "OL-7F3A" }`.
- Teks pesan disimpan di file lokalisasi (`.arb`), bukan di kode layar.
- Buat **halaman galeri feedback** di build debug untuk memeriksa semua toast, banner, dan dialog sekaligus.

---

## 13. Prioritas pengerjaan (mengikuti roadmap)

| Fase | Layar & komponen UI |
|---|---|
| **Fase 0** | Design tokens + theme Flutter · komponen dasar · set ikon D.1 · ilustrasi state (D.2) · Lottie inti: splash, loading, sukses, error, sinkron (D.3) · sistem feedback `AppFeedback` + format error API seragam (§12) · splash & cek versi · login, login pertama, lupa password · pengalih peran & cabang · Akun · pusat notifikasi · pencarian global · state kosong/loading/error · kunci aplikasi · matriks akses (§7) |
| **Fase 1** | Jadwal terapis · Rekam sesi (BodyMap, PainScale, TreatmentChips) · Detail pasien & grafik nyeri · Home visit & check-in · Intake QR · SyncIndicator & offline · mulai/akhiri sesi & tidak datang · tab Riwayat & detail sesi · jadwal minggu & ketersediaan · Antrian kasir · buat/ubah jadwal · daftar & form data pasien · alur pengecualian §6.3 (walk-in, terlambat, ganti terapis) |
| **Fase 2** | Kasir & PaymentMethodSelector · siklus status & alur pembayaran §6.4 (tunai, QRIS, VA/transfer, paket, poin, gabungan, link bayar) · tagihan home visit oleh terapis · diskon & persetujuan · refund berdampak kuota/poin/komisi · kas terapis · rekonsiliasi gateway & piutang · Paket & UpsellCard · Tutup kas · riwayat transaksi & refund · jual paket · pratinjau struk · booking masuk dari website · Komisi saya · Dashboard owner (KpiTile, grafik, ActionAlert) · Laporan · Persetujuan · rekap komisi · kelola staf, layanan & harga, paket, aturan komisi, template · audit log |
| **Fase 3** | Aplikasi pasien end-to-end (onboarding OTP, hubungkan data lama, booking, jadwal saya, latihan + video, riwayat, paket & struk, poin & referral, profil) · kirim program latihan (terapis) · kelola cabang · multi-cabang di filter · tema gelap |

---

## 14. Kriteria selesai (Definition of Done) per layar

- [ ] Memakai token dari §2, tanpa warna/ukuran hardcode
- [ ] Hanya memakai ikon Phosphor, ilustrasi unDraw & animasi dari Lampiran D (tanpa pustaka ikon lain); animasi mengikuti "kurangi gerakan"
- [ ] 4 state lengkap: isi · kosong · loading · error
- [ ] Semua popup, toast & error lewat `AppFeedback` dan memakai katalog §12 (tanpa dialog/snackbar buatan sendiri)
- [ ] Lolos uji text scale 160% tanpa teks terpotong
- [ ] Target sentuh ≥ 48dp, kontras ≥ 4.5:1
- [ ] Bekerja offline sesuai §8 (untuk layar yang menulis data)
- [ ] Data sensitif mengikuti hak akses §10
- [ ] Diuji di 1 HP Android kelas menengah (RAM 4GB) & 1 iPhone
- [ ] Diuji langsung oleh minimal 1 terapis / kasir di klinik
- [ ] Akses sesuai matriks §7 (diuji dengan akun tiap peran)
- [ ] Alur §6.1 berjalan utuh lintas peran di lingkungan staging sebelum rilis fase
- [ ] Semua butir requirement layar di Lampiran A (input, validasi, aturan, edge case) terpenuhi dan diuji per ID layar

---

## 15. Metrik keberhasilan

| Metrik | Target awal |
|---|---|
| Median waktu rekam sesi | ≤ 60 detik |
| Sesi tercatat di hari yang sama | ≥ 95% |
| Transaksi kasir per pasien | ≤ 45 detik (tanpa QRIS menunggu) |
| Item gagal sinkron > 24 jam | 0 |
| Pasien aktif buka aplikasi pasien / minggu | ≥ 40% (Fase 3) |

---

## 16. Pertanyaan untuk workshop

1. Daftar treatment & area tubuh final per layanan — siapa yang menyusun template?
2. Aturan komisi: per layanan, per titik, atau per home visit?
3. Radius check-in home visit & kebijakan bila di luar radius.
4. Apakah screenshot data medis perlu diblokir?
5. Siapa saja yang boleh melihat nomor telepon & rontgen?
6. Perlu dukungan HP Android versi lama / layar kecil (≤ 5,5")?
7. Batas waktu terapis boleh mengedit catatan sesi (usulan: 24 jam, setelahnya addendum).
8. Batas waktu pasien boleh ubah/batalkan jadwal sendiri (usulan: H-1 pukul 18.00).
9. Apakah pembayaran sebagian / utang diizinkan? Berapa nominal refund yang butuh persetujuan owner?
10. Pengaturan mana yang cukup di panel admin web, dan mana yang wajib ada di aplikasi owner?
11. Booking dari pasien: otomatis diterima bila slot kosong, atau selalu dikonfirmasi front desk?
12. Perlu printer struk Bluetooth, atau cukup struk WhatsApp?
13. Perlu DP / bayar di muka saat booking online? Berapa persen, dan apa aturan hangus bila tidak datang?
14. Batas diskon manual tanpa persetujuan owner, dan batas pemakaian poin per transaksi.
15. Gateway yang dipilih (Midtrans / Xendit) — menentukan dukungan refund otomatis & e-wallet.
16. Perlu peran **Admin klinik** terpisah dari Owner (akses operasional penuh tanpa laporan keuangan & kelola harga)? Akun `admin`/`user` lama dipetakan ke peran apa (A.1)?
17. Terapis boleh mencari & melihat semua pasien, atau hanya pasien yang pernah/akan ditanganinya?
18. Batas booking aktif per pasien & batas waktu DP sebelum booking batal otomatis.

---

## Lampiran A — Katalog layar & requirement

### A.0 Aturan yang berlaku untuk semua layar

Kecuali disebut lain, **setiap layar** wajib:
- Punya 4 state: isi · kosong · loading (Skeleton) · error (katalog §12.4).
- Menampilkan/menyembunyikan data & aksi sesuai matriks §7; API tetap memvalidasi.
- Memakai `AppFeedback` (§12) untuk semua toast, banner, dialog.
- Daftar memakai ListPaging (20/halaman) + tarik untuk refresh.
- Layar yang menulis data: autosave draf lokal, aman saat offline (§8), tidak kehilangan isian saat error.
- Tombol aksi utama dinonaktifkan + spinner selama request berjalan (mencegah kirim ganda).
- Format: tanggal `Sel, 6 Okt 2026`, jam `09.00` WIB, uang `Rp450.000`, nomor pasien `#0412`.
- Deep link dari notifikasi membuka layar tujuan langsung, dengan tombol kembali ke tab asal.

Format setiap entri: **Masuk dari** · **Data** · **Input & validasi** · **Aksi** · **Aturan** · **Edge case** · **Fase**.

### A.1 Pemetaan peran dari sistem lama

| Sistem lama (`users.role`) | Peran baru | Catatan |
|---|---|---|
| `admin` | **Owner** atau **Admin klinik** | Admin klinik = akses owner tanpa laporan keuangan & kelola harga (putuskan di workshop) |
| `user` | **Terapis** atau **Kasir / front desk** | Dipilih per akun saat migrasi |
| — (baru) | **Pasien** | Akun terpisah di Aplikasi Pasien, login OTP |

Satu akun staf boleh punya beberapa peran; peran aktif dipilih di UM-08.

### A.2 Pemetaan data rekam medis lama → rekam sesi baru

Agar tidak ada data yang hilang saat migrasi dan di layar baru.

| Kolom lama (`perawatan`) | Di layar baru (TR-04) | Bentuk input |
|---|---|---|
| `keluhan` | Keluhan | Prefill dari intake/sesi lalu, teks singkat |
| `penyebab` | Penyebab cedera | Pilihan (olahraga, jatuh, kerja, kecelakaan, lainnya) + teks |
| `lama_cedera` | Lama cedera | Angka + satuan (hari/minggu/bulan/tahun) |
| `bagian` | Area ditangani | BodyMap (kode area) |
| `bagian_penenang` | Area relaksasi/penenang | BodyMap mode kedua (warna berbeda) |
| `analisa` | Analisa terapis | Teks + pilihan cepat dari template |
| `treatment` | Treatment | TreatmentChips + teks tambahan |
| `kesimpulan` | Kesimpulan & saran | Teks + pilihan cepat ("kontrol 1 minggu", "latihan rumah") |
| `terapis` | Terapis | Otomatis dari akun (bukan teks bebas) |
| `hasil_rontgen` | Lampiran rontgen | AttachmentRow (link lama tetap bisa dibuka) |
| — (baru) | Skala nyeri sebelum/sesudah | PainScale |
| — (baru) | Durasi sesi | Otomatis dari Mulai → Selesai |

Data pasien lama (`data_pasiens`: nomor, nama, ttl, tempat_lahir, tlp, alamat, gender, instansi, hobi, tb, bb) dipakai utuh di KS-04 / PS-18.

---

### A.3 Umum — semua staf (UM)

#### UM-01 Splash & cek versi
- **Masuk dari:** buka aplikasi.
- **Data:** token tersimpan, versi minimum & status pemeliharaan dari API.
- **Aksi:** otomatis → UM-07 (bila token valid & kunci aktif) / beranda peran / UM-04.
- **Aturan:** maks 2 dtk; bila API tidak terjangkau tapi token & data lokal ada → masuk mode offline dengan banner.
- **Edge case:** pertama kali buka tanpa koneksi → layar "Butuh koneksi untuk masuk pertama kali" + Coba lagi.
- **Fase:** 0

#### UM-02 Perbarui aplikasi
- **Masuk dari:** UM-01 bila versi < minimum.
- **Data:** versi terpasang, versi terbaru, catatan rilis singkat.
- **Aksi:** "Perbarui" → Play Store / App Store. Wajib: tidak bisa ditutup. Opsional: banner di beranda dengan "Nanti".
- **Edge case:** ada data belum tersinkron → sinkron dulu sebelum mengarahkan ke store.
- **Fase:** 0

#### UM-03 Pemeliharaan
- **Masuk dari:** API mengembalikan status pemeliharaan.
- **Data:** pesan, perkiraan selesai.
- **Aksi:** Coba lagi. Mode offline tetap bisa dipakai untuk rekam sesi.
- **Fase:** 0

#### UM-04 Login
- **Masuk dari:** UM-01, logout, `auth_expired`.
- **Input & validasi:** username (wajib, tanpa spasi) · password (wajib, tampil/sembunyi). "Ingat perangkat ini".
- **Aksi:** Masuk · Lupa password (UM-06).
- **Aturan:** gagal 5× → kunci 5 menit dengan hitung mundur; pesan tidak membedakan "username salah" vs "password salah". Akun nonaktif → "Akun ini dinonaktifkan. Hubungi admin."
- **Edge case:** keyboard menutupi tombol → layar bisa di-scroll; paste password diizinkan.
- **Fase:** 0

#### UM-05 Login pertama
- **Masuk dari:** UM-04 bila akun bertanda password sementara.
- **Langkah:** (1) ganti password: minimal 8 karakter, beda dari sementara, konfirmasi cocok, indikator kekuatan → (2) atur PIN 6 digit (konfirmasi) + opsi biometrik → (3) izin notifikasi dengan penjelasan → (4) pilih cabang/peran bila >1.
- **Aturan:** tidak bisa dilewati kecuali izin notifikasi & biometrik.
- **Fase:** 0

#### UM-06 Lupa password
- **Input & validasi:** username (wajib) + catatan opsional.
- **Aksi:** "Minta reset ke admin" → masuk OW-06 Persetujuan.
- **Aturan:** respons selalu sama ("Permintaan terkirim bila akun terdaftar") agar username tidak bisa ditebak.
- **Fase:** 0

#### UM-07 Kunci aplikasi
- **Masuk dari:** buka ulang setelah tidak aktif ≥ 5 menit.
- **Input:** PIN 6 digit / biometrik.
- **Aturan:** salah 5× → logout paksa (data lokal yang belum sinkron tetap disimpan terenkripsi). Konten layar disamarkan di app switcher.
- **Aksi:** "Lupa PIN" → login ulang dengan password.
- **Fase:** 0

#### UM-08 Pilih cabang & peran
- **Masuk dari:** UM-05, Akun, AppHeader (ketuk nama cabang).
- **Data:** daftar cabang & peran yang dimiliki akun.
- **Aksi:** pilih → beranda peran itu dimuat ulang.
- **Aturan:** ganti cabang ditolak bila ada sesi Berjalan atau tagihan Menunggu pembayaran milik akun ini.
- **Fase:** 0 (multi-cabang aktif di Fase 3)

#### UM-09 Pusat notifikasi
- **Masuk dari:** ikon lonceng (badge jumlah belum dibaca, maks "99+").
- **Data:** NotificationItem; tab Semua / Belum dibaca; kelompok Hari ini / Kemarin / Lebih lama.
- **Aksi:** ketuk → deep link & tandai dibaca · tandai semua dibaca · geser untuk hapus.
- **Jenis per peran:** Terapis: sesi baru/berubah/batal, pasien hadir, program latihan dibalas pasien, komisi disetujui, cuti disetujui/ditolak. Kasir: booking masuk, sesi selesai (siap ditagih), pembayaran lunas/gagal, kas terapis menunggu diterima. Owner: persetujuan baru, tutup kas terkirim, selisih kas, pengumuman sistem.
- **Aturan:** riwayat disimpan 90 hari. Target deep link yang sudah tidak ada → `not_found`.
- **Fase:** 0

#### UM-10 Pencarian global
- **Masuk dari:** ikon cari di AppHeader.
- **Input:** min 2 karakter; nama, `#nomor`, atau 4 digit akhir HP (hanya peran berwenang).
- **Data:** kelompok hasil: Pasien · Sesi hari ini · Transaksi (kasir/owner).
- **Aturan:** terapis hanya melihat pasien yang pernah/akan ditanganinya kecuali owner mengizinkan semua. Riwayat 5 pencarian terakhir, bisa dihapus.
- **Fase:** 0

#### UM-11 Akun
- **Data:** foto, nama, peran aktif, cabang aktif, versi app.
- **Menu:** Ganti peran/cabang (UM-08) · Ubah password & PIN (UM-12) · Pengaturan notifikasi (UM-13) · Tampilan (tema, ikut sistem) · Status sinkron (UM-14) · Kas dibawa (terapis, TR-11) · Kelola (owner, lihat Lampiran B.1) · Bantuan & kebijakan (UM-15) · Logout.
- **Aturan:** logout dengan data belum sinkron → dialog §12.5.
- **Fase:** 0

#### UM-12 Ubah password & PIN
- **Input & validasi:** password lama (wajib) · password baru (aturan UM-05) · konfirmasi. PIN lama → PIN baru → konfirmasi. Toggle biometrik.
- **Aturan:** setelah ganti password, sesi di perangkat lain dikeluarkan.
- **Fase:** 0

#### UM-13 Pengaturan notifikasi
- **Data:** toggle per jenis notifikasi (UM-09) + jam tenang (mis. 21.00–07.00, kecuali yang mendesak).
- **Aturan:** notifikasi keamanan & persetujuan wajib tidak bisa dimatikan. Izin OS ditolak → banner + tombol ke pengaturan.
- **Fase:** 0

#### UM-14 Status sinkron
- **Masuk dari:** SyncIndicator, Akun.
- **Data:** daftar item antre: jenis, pasien, waktu dibuat, status (menunggu/mengirim/gagal + alasan).
- **Aksi:** Coba lagi semua · coba lagi per item · lihat detail · "Kirim log ke tim".
- **Aturan:** item tidak bisa dihapus dari sini oleh staf biasa (mencegah kehilangan catatan medis).
- **Fase:** 1

#### UM-15 Bantuan & kebijakan
- **Data:** FAQ singkat per peran, kontak dukungan (WA VELTECH/admin), kebijakan privasi, syarat penggunaan, lisensi open source, versi.
- **Fase:** 0

---

### A.4 Terapis (TR)

#### TR-01 Beranda / Jadwal hari ini (tab Jadwal)
- **Data:** sapaan, 3 ringkasan (sesi, home visit, pasien baru), strip 7 hari, daftar SessionCard (jam, pasien, layanan, ruang/lokasi, status, tag home visit/pasien baru, "berikutnya dalam n mnt").
- **Aksi:** ketuk kartu → TR-05 (sebelum sesi) atau TR-04 (sesi Berjalan) · Mulai sesi (status Hadir) · menu ⋯: Tidak datang (alasan wajib) · Minta pindah jadwal (alasan + usulan jam) · Buka home visit (TR-09) · ikon kalender → Jadwal minggu (TR-02).
- **Aturan:** "Mulai sesi" hanya aktif untuk status Hadir (atau Dijadwalkan untuk home visit setelah check-in). Hanya 1 sesi Berjalan per terapis.
- **Edge case:** pasien terlambat >15 mnt → banner di kartu (§6.3). Sesi dipindahkan oleh kasir → kartu ditandai "Diubah" + notifikasi.
- **Fase:** 1

#### TR-02 Jadwal minggu & ketersediaan
- **Masuk dari:** TR-01 (tampilan minggu).
- **Data:** grid 7 hari × jam operasional cabang; sesi, blok tidak tersedia, cuti (status Menunggu/Disetujui/Ditolak).
- **Aksi:** tandai jam tidak tersedia (berulang/sekali) · Ajukan cuti (TR-03).
- **Aturan:** blok yang bertabrakan dengan sesi Dijadwalkan ditolak dengan pesan berisi sesi yang bentrok.
- **Fase:** 1

#### TR-03 Ajukan cuti
- **Input & validasi:** tanggal mulai–selesai (wajib, tidak di masa lalu) · seharian/jam tertentu · alasan (pilihan + catatan).
- **Aksi:** Kirim → OW-06. Batalkan pengajuan selama Menunggu.
- **Aturan:** bila ada sesi di rentang itu → tampilkan jumlahnya; owner yang memindahkan (KS-08).
- **Fase:** 1

#### TR-04 Rekam sesi
- **Masuk dari:** TR-01 (Mulai sesi / sesi Berjalan), FAB, TR-14.
- **Data:** header pasien (nama, #nomor, layanan, timer sesi), banner peringatan medis, prefill dari sesi lalu & intake.
- **Input & validasi (urutan layar):** Keluhan* · Area ditangani* (BodyMap) · Area penenang (BodyMap mode 2) · Skala nyeri sebelum* & sesudah* (PainScale) · Penyebab & lama cedera (wajib hanya di sesi pertama cedera tsb.) · Analisa · Treatment* (min 1 chip) · Kesimpulan & saran · Lampiran (foto/rontgen maks 10 file, 10 MB/file; catatan suara maks 2 mnt) · Item tambahan untuk tagihan (titik tambahan, tambahan cedera) — lihat A.2.
- **Aksi:** Simpan & kirim ringkasan ke pasien · Simpan saja · Selesaikan sesi (status → Selesai, tagihan Draft terbentuk).
- **Aturan:** autosave lokal tiap perubahan; keluar tanpa simpan → dialog §12.5. "Selesaikan sesi" butuh field wajib terisi. Ringkasan ke pasien tidak memuat Analisa (catatan internal).
- **Edge case:** offline → simpan lokal + SyncIndicator; lampiran diunggah belakangan. App tertutup paksa → draf dipulihkan saat dibuka.
- **Fase:** 1

#### TR-05 Detail pasien
- **Masuk dari:** TR-01, TR-06, UM-10, notifikasi.
- **Data:** header (inisial, nama, #nomor, umur, gender, hobi/instansi, TB/BB) · cedera aktif · grafik tren nyeri · paket aktif & sisa kuota · program latihan aktif & kepatuhan (% hari selesai) · riwayat sesi (ListPaging) · Catatan lama (data sistem lama, baca-saja) · lampiran.
- **Aksi:** Rekam sesi (bila ada sesi Berjalan) · Kirim program latihan (TR-13) · buka detail sesi (TR-08).
- **Aturan:** nomor telepon & alamat disamarkan untuk terapis kecuali saat home visit aktif. Tidak bisa mengedit identitas (itu KS-04).
- **Fase:** 1

#### TR-06 Pasien saya (tab Pasien)
- **Data:** SearchBar + FilterChips (Semua · Aktif bulan ini · Belum kembali >30 hari · Paket hampir habis); item: nama, #nomor, kunjungan terakhir, cedera aktif.
- **Aksi:** ketuk → TR-05.
- **Fase:** 1

#### TR-07 Riwayat (tab Riwayat)
- **Data:** sesi yang ditangani, kelompok per tanggal, filter periode & status; badge "Belum lengkap" / "Belum tersinkron".
- **Aksi:** ketuk → TR-08.
- **Fase:** 1

#### TR-08 Detail sesi & addendum
- **Data:** semua isian TR-04, lampiran, durasi, status pembayaran sesi (badge saja, tanpa nominal untuk terapis), riwayat perubahan.
- **Aksi:** Edit (≤ 24 jam, hanya pembuat) · Tambah addendum (setelah 24 jam) · Hapus catatan (dialog §12.5, hanya pembuat/admin).
- **Aturan:** setiap edit/addendum tercatat (siapa, kapan, apa). Sesi yang tagihannya Lunas tidak bisa mengubah item tagihan.
- **Fase:** 1

#### TR-09 Home visit
- **Data:** pasien, layanan, jam, alamat + patokan, peta mini, jarak & ETA, catatan medis penting, checklist alat (dari template layanan), status check-in/out.
- **Aksi:** Buka Maps · Hubungi pasien (lewat nomor yang disamarkan/klinik) · Check-in · Mulai sesi → TR-04 · Check-out · Batalkan di lokasi (alasan wajib + foto opsional) · Tagih (TR-10).
- **Aturan:** check-in dalam radius cabang (default 200 m); di luar radius → `checkin_out_of_range`. Check-out wajib sebelum tagih. Ongkos transport dihitung dari jarak cabang → alamat.
- **Edge case:** GPS ditolak → `perm_location`; GPS tidak akurat (>100 m) → tunggu / check-in manual dengan alasan.
- **Fase:** 1 (tagih: Fase 2)

#### TR-10 Tagih di lokasi
- **Data:** item dari sesi + ongkos transport, potongan member, total.
- **Aksi:** QRIS (QrisPanel) · Tunai (CashCalculator) · Pakai paket · Kirim link bayar · Tagih nanti di klinik.
- **Aturan:** terapis tidak bisa menambah diskon manual atau mengubah harga. Tunai → TR-11.
- **Fase:** 2

#### TR-11 Kas dibawa & serah terima
- **Masuk dari:** Akun.
- **Data:** total tunai yang diterima per hari + rincian transaksi; status: Dibawa · Diserahkan (menunggu konfirmasi kasir) · Diterima.
- **Aksi:** "Serahkan ke kasir" (pilih kasir) → kasir konfirmasi di KS-16.
- **Aturan:** kas yang belum diserahkan >1 hari kerja → notifikasi ke terapis & owner.
- **Fase:** 2

#### TR-12 Komisi saya
- **Data:** periode (default bulan berjalan), total sesi, home visit, estimasi komisi, status (Estimasi / Disetujui / Dibayar), rincian per sesi (tanggal, pasien inisial, layanan, nilai).
- **Aturan:** sesi yang di-refund tampil dengan koreksi negatif. Nominal pembayaran pasien tidak ditampilkan, hanya komisi.
- **Fase:** 2

#### TR-13 Kirim program latihan
- **Masuk dari:** TR-05, setelah TR-04.
- **Input & validasi:** pilih latihan dari pustaka (OW-15; cari + filter area tubuh) · per latihan: set, repetisi/durasi, frekuensi per hari · tanggal mulai–selesai · catatan untuk pasien.
- **Aksi:** Pratinjau tampilan pasien · Kirim (push + WA ke pasien).
- **Aturan:** pasien tanpa Aplikasi Pasien → dikirim sebagai pesan WA berisi link video.
- **Fase:** 3

#### TR-14 Pilih pasien (FAB)
- **Masuk dari:** FAB bila tidak ada sesi Berjalan.
- **Data:** sesi hari ini berstatus Hadir · pencarian pasien.
- **Aksi:** pilih sesi Hadir → Mulai sesi → TR-04. Pasien tanpa sesi → "Minta kasir buat sesi" (notifikasi ke front desk).
- **Aturan:** terapis tidak membuat sesi sendiri (agar tagihan & jadwal tetap satu pintu).
- **Fase:** 1

---

### A.5 Kasir / front desk (KS)

#### KS-01 Antrian hari ini (tab Antrian)
- **Data:** kolom/segmen status: Dijadwalkan · Hadir · Berjalan · Selesai (belum bayar); per item: jam, pasien, terapis, ruang, tag; penanda terlambat.
- **Aksi:** Tandai hadir · tetapkan/ganti terapis & ruang · + Sesi tanpa jadwal (walk-in) · ketuk Selesai → KS-09 · menu ⋯: pindah jadwal, batalkan (alasan), tidak datang.
- **Aturan:** ganti terapis hanya ke terapis yang slotnya kosong. Pasien baru belum lengkap datanya → tanda "Lengkapi data" sebelum Tandai hadir.
- **Fase:** 1

#### KS-02 Intake QR & verifikasi
- **Masuk dari:** FAB.
- **Data:** QR besar (link ke WB-01, berlaku per cabang, bisa diganti), daftar "baru masuk" real-time.
- **Aksi:** ketuk entri → form verifikasi (isian WB-01, bisa dikoreksi) → Buat pasien (atau gabung ke pasien lama bila `duplicate_patient`) → Jadwalkan / Tandai hadir.
- **Aturan:** nomor pasien dibuat server saat disimpan (bukan max+1 di klien). Entri tidak diproses >24 jam → ditandai.
- **Fase:** 1

#### KS-03 Daftar pasien (tab Pasien)
- **Data:** SearchBar, FilterChips (cabang, aktif/arsip, punya paket, belum kembali >30 hari, punya tagihan belum lunas); item: nama, #nomor, kunjungan terakhir, paket aktif.
- **Aksi:** ketuk → KS-05 · Tambah pasien → KS-04.
- **Fase:** 1

#### KS-04 Tambah / edit data pasien
- **Input & validasi:** Identitas: nama* (2–100 huruf), tanggal lahir* (tidak di masa depan, umur ≤ 120), tempat lahir, gender* · Kontak: HP* (format Indonesia 08…/+62, 10–14 digit), alamat (+ pin peta untuk home visit), kontak darurat (opsional) · Fisik: TB (cm, 50–250), BB (kg, 2–300) · Lainnya: instansi, hobi/olahraga, sumber tahu klinik · Persetujuan data* (ConsentCheckbox, pasien baru).
- **Aksi:** Simpan · Arsipkan (dialog §12.5, bukan hapus).
- **Aturan:** nomor pasien otomatis & baca-saja; cek ganda (nama + tanggal lahir, atau HP) sebelum simpan. Perubahan tercatat di audit log.
- **Fase:** 1

#### KS-05 Detail pasien (kasir)
- **Data:** identitas & kontak lengkap, paket & kuota, poin, tagihan belum lunas, jadwal mendatang, riwayat kunjungan (tanggal, terapis, layanan, status bayar) — catatan medis hanya ringkasan.
- **Aksi:** Edit (KS-04) · Buat jadwal (KS-06) · Jual paket (KS-12) · Tagih sisa (KS-09) · Kirim link bayar.
- **Fase:** 1

#### KS-06 Buat / ubah jadwal
- **Langkah & validasi:** pasien* → layanan* (durasi otomatis) → lokasi*: cabang/ruang atau home visit (alamat wajib) → terapis (atau "siapa saja") → SlotPicker* → catatan → ringkasan.
- **Aturan:** slot dihitung dari jam operasional, durasi layanan, ketersediaan terapis & ruang; bentrok tidak bisa dipilih. Pasien mendapat notifikasi saat dibuat/diubah. Ubah jadwal menyimpan jejak jadwal lama.
- **Fase:** 1

#### KS-07 Booking masuk
- **Masuk dari:** tab Antrian (segmen "Booking masuk" + badge), notifikasi.
- **Data:** sumber (website/app), pasien (lama/baru), layanan, jam yang diminta, catatan, status DP.
- **Aksi:** Terima (slot dikunci) · Usulkan jam lain (SlotPicker) · Tolak (alasan wajib; DP dikembalikan otomatis bila ada).
- **Aturan:** booking tidak direspons dalam n jam → pengingat ke front desk. Slot yang diminta sudah terisi → hanya "Usulkan jam lain".
- **Fase:** 2

#### KS-08 Pindah sesi massal
- **Masuk dari:** OW-02 / KS-01 (pilih terapis → "Pindahkan sesi"), persetujuan cuti.
- **Data:** daftar sesi terdampak.
- **Aksi:** pilih terapis pengganti per sesi (yang slotnya kosong) atau pindah jam · kirim pemberitahuan ke pasien (pratinjau pesan).
- **Aturan:** sesi tanpa pengganti tetap ditandai "Perlu tindakan".
- **Fase:** 1

#### KS-09 Tagihan (tab Kasir)
- **Data (tab Kasir):** segmen Belum bayar · Menunggu pembayaran · Belum lunas · Hari ini (lunas); akses cepat Riwayat transaksi (KS-13) & Tutup kas (KS-17).
- **Data (detail tagihan):** pasien, terapis, tanggal sesi, item (MoneyRow), potongan berurutan (§6.4.4), total, sisa, PaymentStatusBadge.
- **Input & validasi:** tambah item dari daftar layanan · voucher (kode valid, berlaku, cabang cocok, kuota tersedia) · diskon manual (nominal/persen + alasan; > batas → `discount_needs_approval`) · poin.
- **Aksi:** Terbitkan (Draft → Belum bayar) · Bayar (KS-10) · Batalkan (dialog §12.5).
- **Aturan:** item terkunci setelah Terbitkan. Harga diambil dari pricelist saat sesi, bukan saat bayar.
- **Fase:** 2

#### KS-10 Pembayaran
- **Data:** total, sisa, PaymentMethodSelector.
- **Per metode:** Tunai: CashCalculator, uang diterima ≥ sisa (atau bayar sebagian bila diizinkan) · QRIS: QrisPanel, kedaluwarsa (mis. 15 mnt) · Transfer/VA: tampilkan nomor VA + salin, atau transfer manual (bank*, nominal* = sisa, foto bukti*) → KS-15 · Paket: pilih paket, kuota sebelum/sesudah · Poin: jumlah ≤ saldo & ≤ batas · Link bayar: kirim ke WA pasien.
- **Aturan:** pembayaran gabungan: setiap metode mengurangi sisa sampai 0. `payment_double_guard` bila tagihan sudah Lunas/Menunggu. QRIS & VA butuh koneksi.
- **Fase:** 2

#### KS-11 Konfirmasi pembayaran & struk
- **Data:** centang besar, nominal, metode (+ ref), kembalian, sisa kuota paket, poin didapat.
- **Aksi:** Kirim struk WA (otomatis, bisa kirim ulang) · Pratinjau/cetak struk · Selesai (kembali ke antrian).
- **Aturan:** isi struk §6.4.5. Nomor struk berurutan per cabang dari server.
- **Fase:** 2

#### KS-12 Jual paket / membership
- **Input & validasi:** pasien* · paket* (aktif di cabang ini) · tanggal mulai (default hari ini) · voucher/diskon.
- **Aksi:** Lanjut bayar (KS-10) → kuota aktif setelah Lunas.
- **Aturan:** paket sejenis masih aktif → tampilkan peringatan "masih sisa n sesi" + pilihan perpanjang.
- **Fase:** 2

#### KS-13 Riwayat transaksi & detail
- **Data:** daftar per tanggal; filter metode, status, kasir/terapis penagih; detail: item, pembayaran (bisa >1 metode), riwayat status, ref gateway.
- **Aksi:** Kirim ulang struk · Ajukan refund/batal (KS-14) · Lunasi sisa.
- **Fase:** 2

#### KS-14 Refund / batal transaksi
- **Input & validasi:** jenis (penuh/sebagian) · item atau nominal (≤ yang dibayar) · alasan* (pilihan + catatan) · metode pengembalian* · bukti (wajib untuk manual).
- **Data:** ringkasan dampak: kuota paket, poin, komisi terapis, omzet.
- **Aksi:** Ajukan (di atas batas → OW-06) / Proses (di bawah batas) → dialog §12.5.
- **Aturan:** setelah tutup kas → hanya owner (§6.4.6). Refund gateway tidak didukung → `refund_not_supported`.
- **Fase:** 2

#### KS-15 Verifikasi transfer manual
- **Data:** daftar "Menunggu verifikasi": pasien, nominal, bank, waktu, foto bukti (bisa diperbesar).
- **Aksi:** Setujui → Lunas · Tolak (alasan wajib; pasien diberi tahu).
- **Aturan:** yang mengunggah bukti tidak boleh memverifikasi transaksinya sendiri.
- **Fase:** 2

#### KS-16 Terima kas terapis
- **Data:** serah terima masuk: terapis, total, rincian.
- **Input:** jumlah fisik diterima*.
- **Aksi:** Terima (cocok) · Terima dengan selisih (catatan wajib, notifikasi ke owner).
- **Fase:** 2

#### KS-17 Tutup kas harian
- **Data:** per metode: tercatat sistem vs. dihitung; kas terapis yang sudah/ belum diterima; transaksi Menunggu yang masih terbuka.
- **Input & validasi:** jumlah tunai fisik* · catatan (wajib bila selisih ≠ 0).
- **Aksi:** Tutup kas → terkirim ke owner; transaksi hari itu terkunci.
- **Aturan:** tidak bisa tutup bila masih ada pembayaran QRIS/VA Menunggu (harus diselesaikan atau dibatalkan dulu).
- **Fase:** 2

#### KS-18 Piutang
- **Masuk dari:** tab Kasir (segmen Belum lunas), KS-05.
- **Data:** pasien, sisa, umur piutang, terakhir diingatkan.
- **Aksi:** Kirim link bayar / pengingat (per pasien atau terpilih) · Lunasi.
- **Fase:** 2

---

### A.6 Owner (OW)

#### OW-01 Ringkasan (tab Ringkasan)
- **Data:** filter periode & cabang; KpiTile omzet (+delta); grafik mingguan; % pasien kembali; % slot terisi; sesi per terapis; ActionAlert (pasien belum kembali, piutang >7 hari, selisih kas, persetujuan menunggu).
- **Aksi:** ketuk KPI → OW-04 terfilter · ActionAlert → OW-20 / KS-18 / OW-06.
- **Aturan:** angka "hari ini" diperbarui tiap 5 mnt; tampilkan "diperbarui hh.mm".
- **Fase:** 2

#### OW-02 Jadwal semua terapis (tab Jadwal)
- **Data:** tampilan hari: kolom per terapis (geser horizontal); tampilan minggu: okupansi per terapis; cuti & blok tidak tersedia.
- **Aksi:** semua aksi KS-06 · Pindahkan sesi (KS-08).
- **Fase:** 1

#### OW-03 Pasien (tab Pasien)
- Sama dengan KS-03 + KS-05, dengan tambahan: lintas cabang · gabungkan pasien ganda (pilih data utama, pratinjau hasil, dialog §12.5) · pulihkan dari arsip · lihat catatan medis lengkap (baca-saja).
- **Fase:** 1

#### OW-04 Laporan (tab Laporan)
- **Sub-laporan:** Omzet & transaksi (per hari/metode/cabang) · Layanan terlaris · Kinerja terapis (sesi, okupansi, rata-rata penurunan nyeri) · Retensi (pasien kembali, program tuntas) · Home visit (jumlah, ongkos transport) · Paket (terjual, kuota terpakai, kedaluwarsa) · Piutang · Refund & diskon.
- **Aksi:** filter periode & cabang · ketuk baris → daftar transaksi/sesi · Ekspor (OW-05).
- **Aturan:** semua grafik punya angka terlihat & tabel alternatif.
- **Fase:** 2

#### OW-05 Ekspor
- **Input:** jenis laporan, periode, format (PDF/Excel), sertakan data kontak (default mati; bila dinyalakan wajib alasan).
- **Aksi:** Buat → file dikirim ke unduhan/email owner.
- **Aturan:** setiap ekspor tercatat di OW-18.
- **Fase:** 2

#### OW-06 Persetujuan
- **Data:** daftar per jenis (cuti, refund/batal, diskon manual, komisi, reset password, selisih kas) dengan badge; detail menampilkan konteks lengkap & pengaju.
- **Aksi:** Setujui · Tolak (alasan wajib) · untuk reset password: buat password sementara (ditampilkan sekali).
- **Aturan:** pengaju diberi tahu hasilnya. Persetujuan tidak bisa dibatalkan; koreksi lewat transaksi baru.
- **Fase:** 2 (cuti & reset password: Fase 1)

#### OW-07 Rekap komisi
- **Data:** periode, per terapis: sesi, home visit, total komisi, penyesuaian (refund), status.
- **Aksi:** buka rincian · Setujui (per terapis/semua) · Tandai dibayar (tanggal + catatan) · Ekspor.
- **Fase:** 2

#### OW-08 Kelola staf
- **Data:** daftar staf: nama, peran, cabang, status (aktif/nonaktif), login terakhir.
- **Input & validasi (tambah/edit):** nama* · username* (unik, 4–30 karakter, huruf kecil/angka/titik) · peran* (≥1) · cabang* (≥1) · HP · password sementara (otomatis).
- **Aksi:** Tambah · Edit · Nonaktifkan/aktifkan (dialog) · Reset password · Keluarkan dari semua perangkat.
- **Aturan:** owner terakhir tidak bisa dinonaktifkan. Staf nonaktif dengan sesi mendatang → minta pindahkan dulu (KS-08).
- **Fase:** 1

#### OW-09 Layanan & harga
- **Input & validasi:** nama* · kategori · durasi* (menit, kelipatan 15) · harga* (≥ 0) · biaya per titik · tambahan cedera · harga member · tersedia untuk home visit · cabang · aktif/nonaktif · template treatment & checklist alat terkait.
- **Aturan:** perubahan harga berlaku untuk tagihan baru; riwayat harga disimpan. Layanan nonaktif tidak muncul di booking.
- **Fase:** 2

#### OW-10 Paket & membership
- **Input & validasi:** nama* · layanan yang dicakup* · jumlah sesi* (≥ 1) · masa berlaku* (hari) · harga* · cabang · aktif.
- **Aturan:** perubahan tidak memengaruhi paket yang sudah terjual.
- **Fase:** 2

#### OW-11 Aturan komisi
- **Input & validasi:** per layanan/home visit/titik: tipe (persen/nominal), nilai* (persen 0–100) · berlaku mulai tanggal · pengecualian per terapis.
- **Aksi:** Pratinjau contoh hitungan · Simpan.
- **Aturan:** aturan baru berlaku untuk sesi mulai tanggal berlaku, tidak mengubah komisi yang sudah disetujui.
- **Fase:** 2

#### OW-12 Voucher & promo
- **Input & validasi:** kode* (unik, huruf besar/angka) · tipe (persen/nominal) · nilai* · minimum transaksi · layanan/cabang berlaku · periode* · kuota total & per pasien · aktif.
- **Data:** pemakaian (berapa kali, total potongan).
- **Fase:** 2

#### OW-13 Aturan poin & referral
- **Input & validasi:** poin per Rp yang dibayar · nilai 1 poin dalam Rp · batas pemakaian per transaksi (%) · masa berlaku poin · hadiah referral (pemberi & penerima) · syarat referral (transaksi pertama lunas).
- **Fase:** 3

#### OW-14 Template
- **Jenis:** template treatment per layanan · daftar area tubuh (kode & nama) · pilihan cepat analisa/kesimpulan · checklist alat home visit · pesan WhatsApp (pengingat H-1, follow-up H+3, pasien >30 hari, struk, link bayar, booking diterima/ditolak, sesi dipindah).
- **Aturan:** variabel yang didukung ditampilkan sebagai chip (`{nama}`, `{jam}`, `{cabang}`, `{terapis}`, `{link}`); pratinjau dengan data contoh; pesan WA mengikuti batas template gateway.
- **Fase:** 1 (treatment & area) · 2 (pesan WA)

#### OW-15 Pustaka latihan
- **Input & validasi:** nama* · area tubuh* · tingkat · video (unggah maks 50 MB atau link) · langkah · set/repetisi default · peringatan.
- **Aturan:** terapis bisa mengusulkan latihan baru → disetujui owner.
- **Fase:** 3

#### OW-16 Pengumuman
- **Input & validasi:** judul* · isi* · penerima (peran/cabang) · jadwal kirim.
- **Aturan:** muncul di UM-09; tidak untuk pasien (pasien lewat OW-20).
- **Fase:** 2

#### OW-17 Cabang & ruang
- **Input & validasi:** nama* · alamat* + titik peta* · jam operasional per hari* · ruang (nama, kapasitas) · radius check-in (50–1000 m) · tarif transport per km · nomor WA cabang.
- **Fase:** 3 (satu cabang sudah ada sejak Fase 1 dengan data dasar)

#### OW-18 Audit log
- **Data:** waktu, staf, aksi (lihat/ubah/hapus/arsip/ekspor/login), objek (pasien/sesi/transaksi), perangkat; filter staf, jenis aksi, tanggal, pasien.
- **Aturan:** baca-saja, tidak bisa dihapus dari aplikasi; disimpan minimal sesuai kebijakan retensi.
- **Fase:** 0 (pencatatan) · 2 (layar)

#### OW-19 Rekonsiliasi gateway
- **Data:** per hari: transaksi sistem vs. settlement gateway, MDR per transaksi, jumlah bersih, status (cocok/selisih/belum settle).
- **Aksi:** buka selisih → detail · Tandai sudah dicek (catatan).
- **Fase:** 2

#### OW-20 Kirim pengingat massal
- **Masuk dari:** ActionAlert, OW-04 retensi.
- **Input:** segmen (belum kembali >n hari, paket hampir habis, piutang) · template pesan · pratinjau penerima (bisa dikecualikan per orang).
- **Aksi:** Kirim → dialog §12.5 dengan jumlah penerima.
- **Aturan:** pasien yang mematikan pesan promo tidak dikirimi; batas 1 pengingat sejenis per pasien per 7 hari.
- **Fase:** 2

---

### A.7 Aplikasi pasien (PS)

#### PS-01 Onboarding
- **Masuk dari:** pertama kali membuka Aplikasi Pasien.
- **Data:** 3 layar: rekam pemulihan, booking mudah, latihan dari terapis.
- **Aksi:** Lewati · Mulai → PS-02.
- **Fase:** 3

#### PS-02 Masuk dengan OTP
- **Input & validasi:** nomor HP* (format Indonesia) → kode OTP 6 digit (berlaku 5 mnt, isi otomatis bila didukung).
- **Aksi:** OTP benar → PS-03 (akun baru) / PS-05 (akun sudah terhubung).
- **Aturan:** kirim ulang setelah 60 dtk, maks 5×/jam; salah 5× → tunggu 15 mnt.
- **Fase:** 3

#### PS-03 Hubungkan data lama / daftar baru
- **Alur:** HP cocok dengan pasien lama → konfirmasi tanggal lahir → terhubung · cocok >1 pasien → pilih nama (tersamarkan sebagian) + tanggal lahir · tidak cocok → form daftar (field = WB-01).
- **Aturan:** gagal konfirmasi 3× → "Hubungi klinik untuk menghubungkan data".
- **Fase:** 3

#### PS-04 Persetujuan data
- **Data:** ringkasan kebijakan + teks lengkap · ConsentCheckbox (data kesehatan*, pesan pengingat*, promo opsional).
- **Aturan:** versi kebijakan baru → diminta setuju ulang saat buka app.
- **Fase:** 3

#### PS-05 Beranda (tab Beranda)
- **Data:** progres pemulihan per cedera aktif · latihan hari ini · sesi berikutnya · poin · tagihan belum lunas (bila ada, kartu warn) · paket hampir habis.
- **Aksi:** Booking ulang (PS-08) · ke latihan (PS-07) · Bayar sekarang (PS-09) · kartu sesi berikutnya → PS-10 (Ubah jadwal → PS-11) · kartu progres → PS-12 · kartu paket → PS-13 · kartu poin → PS-16.
- **Edge case:** pasien baru tanpa riwayat → kartu sambutan + Booking pertama.
- **Fase:** 3

#### PS-06 Latihan (tab Latihan)
- **Data:** program aktif (dari terapis, tanggal berlaku), daftar latihan hari ini dengan centang, kepatuhan minggu ini, program lalu.
- **Aksi:** ketuk → PS-07 · atur pengingat jam latihan.
- **Edge case:** belum ada program → "Terapis Anda akan mengirim latihan setelah sesi."
- **Fase:** 3

#### PS-07 Detail latihan
- **Data:** video (bisa diputar ulang, unduh untuk offline), langkah, set/repetisi, peringatan.
- **Aksi:** Selesai hari ini · Beri catatan untuk terapis (teks, maks 300 karakter; mis. "terasa sakit di…").
- **Aturan:** catatan dengan kata kunci nyeri berat → ditandai di TR-05.
- **Fase:** 3

#### PS-08 Booking
- **Langkah & validasi:** layanan* (harga, durasi) → lokasi*: cabang atau home visit (alamat tersimpan/baru + pin peta; di luar jangkauan → tidak bisa) → terapis (opsional, yang pernah menangani ditampilkan duluan) → SlotPicker* → catatan keluhan → ringkasan (harga, potongan member/poin/voucher, DP bila wajib) → kirim.
- **Aturan:** maks n booking aktif per pasien (mis. 3). Booking terkirim → status Menunggu konfirmasi (atau otomatis Dijadwalkan bila aturan auto-terima).
- **Fase:** 3

#### PS-09 Pembayaran online (DP, paket, pelunasan)
- **Data:** rincian tagihan, total.
- **Aksi:** pilih metode (QRIS, VA, e-wallet) → halaman gateway (WB-02) → kembali ke app → status.
- **Aturan:** status final dari server; saat menunggu tampilkan "Kami sedang menunggu konfirmasi" + cek ulang otomatis. DP tidak dibayar dalam n menit → booking batal otomatis & slot dilepas.
- **Fase:** 3

#### PS-10 Jadwal saya
- **Data:** Mendatang (status: Menunggu konfirmasi/Dijadwalkan) & Lalu (Selesai/Tidak datang/Dibatalkan); detail: layanan, terapis, lokasi + peta, catatan persiapan.
- **Aksi:** Ubah / Batalkan (PS-11) · Tambah ke kalender · Petunjuk arah.
- **Fase:** 3

#### PS-11 Ubah / batalkan jadwal
- **Input:** jadwal baru (SlotPicker) atau alasan batal.
- **Aturan:** hanya sebelum batas waktu (usulan H-1 18.00); setelahnya → "Hubungi klinik" (WA cabang). Aturan DP hangus/dikembalikan ditampilkan sebelum konfirmasi.
- **Fase:** 3

#### PS-12 Riwayat sesi
- **Data:** daftar sesi: tanggal, terapis, layanan; detail: area (gambar BodyMap), nyeri sebelum → sesudah, treatment, kesimpulan & saran (tanpa Analisa internal), latihan yang diberikan.
- **Fase:** 3

#### PS-13 Paket & pembayaran
- **Data:** paket aktif (sisa kuota, berlaku sampai) · tagihan belum lunas · riwayat pembayaran & refund.
- **Aksi:** Beli/perpanjang paket (PS-14) · Bayar sekarang (PS-09) · lihat struk (PS-15).
- **Fase:** 3

#### PS-14 Beli paket
- **Data:** paket yang tersedia di cabang pasien, harga, hemat dibanding per sesi, masa berlaku.
- **Aksi:** Beli → PS-09.
- **Fase:** 3

#### PS-15 Struk
- **Data:** isi struk §6.4.5.
- **Aksi:** Bagikan/simpan sebagai PDF.
- **Fase:** 3

#### PS-16 Poin & referral
- **Data:** saldo & nilai Rp, akan kedaluwarsa, riwayat; kode referral, jumlah teman berhasil, hadiah.
- **Aksi:** Bagikan kode (share sheet) · pakai poin saat booking/bayar.
- **Fase:** 3

#### PS-17 Notifikasi
- **Data:** pengingat jadwal, booking diterima/ditolak/dipindah, latihan baru, pembayaran, promo.
- **Aksi:** ketuk → deep link · pengaturan per jenis (promo bisa dimatikan; pengingat jadwal disarankan tetap aktif).
- **Fase:** 3

#### PS-18 Profil & edit data
- **Input & validasi:** sama dengan KS-04 bagian identitas, kontak, fisik (nomor pasien baca-saja; ganti HP butuh OTP ke nomor baru).
- **Menu:** Jadwal saya (PS-10) · Riwayat sesi (PS-12) · Paket & pembayaran (PS-13) · Poin & referral (PS-16) · Notifikasi (PS-17) · Alamat tersimpan (PS-19) · Persetujuan data (PS-04) · Bahasa & tampilan · Bantuan & kontak klinik · Keluar · Hapus akun (PS-20).
- **Fase:** 3

#### PS-19 Alamat tersimpan
- **Input & validasi:** label (Rumah/Kantor/…) · alamat* · pin peta* · patokan.
- **Aturan:** alamat di luar jangkauan home visit ditandai.
- **Fase:** 3

#### PS-20 Hapus akun
- **Alur:** penjelasan dampak (akun app dihapus; rekam medis disimpan klinik sesuai ketentuan) → konfirmasi OTP → permintaan diproses klinik.
- **Aturan:** sesuai hak subjek data UU PDP; status permintaan bisa dilihat.
- **Fase:** 3

---

### A.8 Halaman web pendukung (WB)

#### WB-01 Form intake via QR (web, tanpa install)
- **Masuk dari:** scan QR di meja (KS-02) atau link WA.
- **Input & validasi:** nama* · tanggal lahir* · tempat lahir · gender* · HP* · alamat · instansi/pekerjaan · hobi/olahraga · TB (angka) · BB (angka) · keluhan* · penyebab · lama cedera (angka + satuan) · foto rontgen (opsional, maks 3) · persetujuan data*.
- **Aturan:** mobile-first, ukuran teks & warna sama dengan app; simpan draf di perangkat; selesai → layar "Terima kasih, silakan tunggu dipanggil" + nomor antrian. Menggantikan Google Form (menutup temuan TB/BB kosong).
- **Fase:** 1

#### WB-02 Halaman bayar gateway
- **Data:** di-host gateway (Midtrans/Xendit) dengan nama & logo One Lotus, nominal, rincian singkat.
- **Aturan:** setelah bayar, redirect ke halaman status One Lotus (berhasil/menunggu/gagal) yang membuka app bila terpasang. Link berlaku sesuai kedaluwarsa tagihan.
- **Fase:** 2

#### WB-03 Booking website (integrasi)
- Form booking di website One Lotus yang sudah ada mengirim ke API yang sama dengan PS-08 → masuk KS-07. Field minimal: nama, HP, layanan, cabang, tanggal & jam yang diinginkan, keluhan.
- **Fase:** 2

---

## Lampiran B — Hasil pengecekan kelengkapan

### B.1 Setiap tab punya layar

| Peran | Tab → layar |
|---|---|
| Terapis | Jadwal → TR-01 · Pasien → TR-06 · + → TR-04/TR-14 · Riwayat → TR-07 · Akun → UM-11 |
| Kasir | Antrian → KS-01 (+ KS-07) · Pasien → KS-03 · + → KS-02/KS-04 · Kasir → KS-09 · Akun → UM-11 |
| Owner | Ringkasan → OW-01 · Jadwal → OW-02 · Pasien → OW-03 · Laporan → OW-04 · Akun → UM-11 (+ menu Kelola: OW-06…OW-20) |
| Pasien | Beranda → PS-05 · Latihan → PS-06 · Booking → PS-08 (+ PS-10 dari kartu jadwal) · Profil → PS-18 (menu: PS-10, PS-12, PS-13, PS-16, PS-17, PS-19, PS-04, PS-20) |

> Menu **Kelola** owner diakses dari Akun owner: Persetujuan (OW-06, juga ikon di AppHeader) · Rekap komisi (OW-07) · Staf (OW-08) · Layanan & harga (OW-09) · Paket (OW-10) · Aturan komisi (OW-11) · Voucher (OW-12) · Poin & referral (OW-13) · Template (OW-14) · Pustaka latihan (OW-15) · Pengumuman (OW-16) · Cabang & ruang (OW-17) · Audit log (OW-18) · Rekonsiliasi (OW-19). OW-20 dari ActionAlert.

### B.2 Setiap langkah alur punya layar

| Alur §6.1 | Layar |
|---|---|
| 1 Booking | PS-08 / WB-03 → KS-07 |
| 2 Pengingat | OW-14 (template) → PS-17 / UM-09 |
| 3 Kedatangan | WB-01 → KS-02 → KS-01 |
| 4 Sesi | TR-01 → TR-04 → TR-08 |
| 5 Pembayaran | KS-09 → KS-10 → KS-11 / TR-10 / PS-09 → WB-02 |
| 6 Tindak lanjut | TR-13 → PS-06 → PS-07 |
| 7 Retensi | OW-01 → OW-20 |
| 8 Akhir hari/bulan | TR-11 → KS-16 → KS-17 · TR-12 · OW-07 · OW-04 · OW-19 |
| Pengecualian §6.3 | KS-01 (walk-in, terlambat) · KS-08 (terapis berhalangan) · TR-09 (batal di lokasi) · KS-09/KS-12 (paket habis) · KS-18 (belum lunas) · OW-03 (gabung data ganda) |
| Refund §6.4.6 | KS-14 → OW-06 |

### B.3 Celah yang ditemukan & ditutup pada pengecekan ini

| # | Celah | Ditutup di |
|---|---|---|
| 1 | Rekam sesi tidak memuat keluhan, penyebab, lama cedera, analisa, bagian penenang, kesimpulan dari sistem lama | A.2, TR-04 |
| 2 | Pemetaan role lama (`admin`/`user`) ke peran baru belum ada | A.1 |
| 3 | Isi tab Kasir, tab Pasien owner, tab Latihan pasien belum didefinisikan | KS-09, OW-03, PS-06 |
| 4 | Form intake QR (sisi pasien) belum punya daftar field | WB-01 |
| 5 | Layar kunci aplikasi, perbarui aplikasi, pemeliharaan, ubah password/PIN, pengaturan notifikasi, status sinkron belum ada | UM-02, UM-03, UM-07, UM-12–UM-14 |
| 6 | FAB terapis tanpa sesi berjalan tidak jelas tujuannya | TR-14 |
| 7 | Serah terima kas terapis ↔ kasir, verifikasi transfer, piutang belum punya layar | TR-11, KS-15, KS-16, KS-18 |
| 8 | Pengelolaan voucher, aturan poin & referral, pustaka latihan, pengumuman belum ada (padahal dipakai di layar lain) | OW-12, OW-13, OW-15, OW-16 |
| 9 | Pindah sesi massal saat terapis berhalangan belum punya layar | KS-08 |
| 10 | Validasi field (format HP, TB/BB, password, OTP, ukuran file) belum ditetapkan | A.3–A.8 |
| 11 | Aplikasi pasien belum punya alamat tersimpan, struk, hapus akun, setuju ulang kebijakan | PS-15, PS-19, PS-20, PS-04 |
| 12 | Baris tabel "Data pasien ganda" salah tempat di §6.4.7 | Dipindah ke §6.3 |
| 13 | Layar pasien Jadwal saya, Riwayat, Paket, Poin tidak punya pintu masuk (tab bar hanya 4) | PS-05 (kartu), PS-18 (menu) |
| 14 | Menu Kelola owner tidak tertaut ke layar mana pun | UM-11, B.1 |

### B.4 Sengaja di luar cakupan versi ini

- Rating/ulasan sesi oleh pasien, chat langsung pasien–terapis, telekonsultasi video.
- Payroll lengkap (komisi berhenti di "Siap dibayar"/"Dibayar").
- Inventaris alat & bahan habis pakai.
- Integrasi BPJS/asuransi.

Bila mitra membutuhkannya, masukkan sebagai fase tambahan setelah workshop.

---

## Lampiran C — Prompt untuk Claude Design

Cara pakai: tempel **C.1 Prompt dasar** sekali di awal, lalu kirim prompt modul (C.2–C.7) satu per satu. Setiap modul menghasilkan artboard ponsel (390×844) yang diberi nama sesuai ID layar. Setelah satu modul jadi, minta revisi per ID ("Revisi TR-04: …") agar perubahan tidak merembet ke layar lain.

### C.1 Prompt dasar (konteks & aturan desain)

```
Kamu mendesain aplikasi mobile "One Lotus" untuk klinik terapi fisik/cedera
One Lotus Personal Therapy (Malang). Ada dua aplikasi:
1) Aplikasi Staf — satu app, menu berubah sesuai peran: Terapis, Kasir/Front desk, Owner.
2) Aplikasi Pasien.
Plus 3 halaman web mobile: form intake via QR, halaman status bayar, booking website.

Ukuran artboard: iPhone 390×844, safe area atas & bawah. Bahasa UI: Bahasa Indonesia
("kamu" untuk staf, "Anda" untuk pasien). Tema terang.

Design tokens (wajib, jangan pakai warna lain):
- bg #F3F8FB · surface #FFFFFF · surfaceAlt #EAF3F9 · line #E1EBF2
- fg #0D2233 · muted #62788A
- brand #0284C7 · brandDeep #0C4A6E · brandSoft #E0F2FE
- gold #C27006 (hanya untuk pendapatan/poin/upsell, maks 1 elemen per layar)
- ok #15803D/#DCF3E4 · warn #A85207/#FDEED6 · crit #B91C1C/#FDE6E6
Font: Plus Jakarta Sans (semua teks), JetBrains Mono (nomor pasien, jam, nominal).
Skala: display 28/800 · title 20/800 · heading 16/700 · body 14/500 (minimum teks baca) ·
caption 12/500. Angka tabular.
Spasi grid 4. Padding layar 16, jarak kartu 12. Radius kartu 16, tombol 12, chip pill,
bottom sheet 24. Kartu pakai border, bukan bayangan. Target sentuh ≥ 48.

Pola wajib:
- AppHeader: konteks kecil (tanggal · cabang) + judul + ikon cari, lonceng (badge), indikator sinkron.
- Tab bar berlabel (ikon + teks), tab aktif warna brand. FAB tengah untuk Terapis & Kasir.
- Status selalu teks + warna (tag pill), tidak pernah warna saja.
- Tombol aksi utama melekat di bawah, di jangkauan jempol.
- Format: "Sel, 6 Okt 2026", "09.00", "Rp450.000", "#0412".
- Data contoh realistis Indonesia (nama, alamat Malang), bukan lorem ipsum.

Tab bar per peran:
- Terapis: Jadwal · Pasien · [+] · Riwayat · Akun
- Kasir: Antrian · Pasien · [+] · Kasir · Akun
- Owner: Ringkasan · Jadwal · Pasien · Laporan · Akun
- Pasien: Beranda · Latihan · Booking · Profil

Beri nama setiap artboard dengan ID layar, mis. "TR-04 Rekam sesi".
Kelompokkan artboard per modul dalam satu baris/section berlabel.
```

### C.2 Modul Umum staf (UM-01 … UM-15)

```
Buat section "UM — Umum staf" berisi 15 artboard:
UM-01 Splash & cek versi (logo lotus, indikator memuat).
UM-02 Perbarui aplikasi (wajib, tombol "Perbarui", catatan rilis singkat).
UM-03 Pemeliharaan (ilustrasi sederhana, perkiraan selesai, "Coba lagi").
UM-04 Login (username, password dengan tampil/sembunyi, "Ingat perangkat ini",
  "Lupa password"; tampilkan juga varian error terkunci 5 menit dengan hitung mundur).
UM-05 Login pertama — buat sebagai 4 langkah dengan indikator langkah:
  ganti password (indikator kekuatan) → atur PIN 6 digit → izin notifikasi → pilih cabang/peran.
UM-06 Lupa password ("Minta reset ke admin").
UM-07 Kunci aplikasi (PIN pad 6 digit + tombol biometrik).
UM-08 Pilih cabang & peran (daftar radio).
UM-09 Pusat notifikasi (tab Semua/Belum dibaca, kelompok Hari ini/Kemarin, item dengan titik belum dibaca).
UM-10 Pencarian global (hasil dikelompokkan Pasien · Sesi hari ini · Transaksi).
UM-11 Akun (profil, peran & cabang aktif, daftar menu sesuai Lampiran A UM-11, logout merah di bawah).
UM-12 Ubah password & PIN.
UM-13 Pengaturan notifikasi (toggle per jenis, jam tenang).
UM-14 Status sinkron (daftar item antre dengan status menunggu/mengirim/gagal, "Coba lagi semua").
UM-15 Bantuan & kebijakan.
```

### C.3 Modul Terapis (TR-01 … TR-14)

```
Buat section "TR — Terapis" berisi 14 artboard, tab bar Terapis:
TR-01 Jadwal hari ini: sapaan "Pagi, Dimas", 3 ringkasan (6 sesi, 2 home visit, 1 pasien baru),
  strip 7 hari, SessionCard berurutan jam dengan status Selesai/Berjalan(menonjol)/Dijadwalkan/Home visit,
  satu kartu dengan banner "Terlambat 15 mnt".
TR-02 Jadwal minggu & ketersediaan (grid 7 hari, blok tidak tersedia, cuti menunggu).
TR-03 Ajukan cuti (form tanggal, seharian/jam, alasan, info "2 sesi terdampak").
TR-04 Rekam sesi (layar terpenting, scroll panjang — tampilkan penuh):
  header pasien + timer sesi; banner peringatan medis merah muda;
  Keluhan; BodyMap depan/belakang dengan area terpilih + chip area; mode Area penenang;
  PainScale 0–10 "7 → 3"; Penyebab & lama cedera; Analisa (pilihan cepat + teks);
  TreatmentChips; Kesimpulan & saran; lampiran (foto rontgen, catatan suara 0:42);
  item tambahan tagihan; indikator "Tersimpan di HP · sinkron otomatis";
  tombol melekat "Simpan & kirim ringkasan ke pasien" + "Selesaikan sesi".
TR-05 Detail pasien (header, cedera aktif, grafik tren nyeri 8→2, paket sisa 1,
  program latihan & kepatuhan, riwayat sesi, bagian "Catatan lama" abu-abu).
TR-06 Pasien saya (search + filter chip + daftar).
TR-07 Riwayat (dikelompokkan per tanggal, badge "Belum lengkap").
TR-08 Detail sesi & addendum (baca-saja, tombol Edit ≤24 jam, riwayat perubahan).
TR-09 Home visit (alamat + peta mini, jarak & ETA, catatan medis, checklist alat,
  tombol Check-in besar, status check-in).
TR-10 Tagih di lokasi (item + ongkos transport, pilihan QRIS/Tunai/Pakai paket/Kirim link).
TR-11 Kas dibawa & serah terima (total hari ini, rincian, "Serahkan ke kasir").
TR-12 Komisi saya (periode, total, status Estimasi, rincian per sesi).
TR-13 Kirim program latihan (pilih dari pustaka, set/repetisi, pratinjau tampilan pasien).
TR-14 Pilih pasien dari FAB (sesi berstatus Hadir + pencarian).
```

### C.4 Modul Kasir / front desk (KS-01 … KS-18)

```
Buat section "KS — Kasir" berisi 18 artboard, tab bar Kasir:
KS-01 Antrian hari ini (segmen status Dijadwalkan/Hadir/Berjalan/Selesai + segmen
  "Booking masuk" dengan badge; tombol "Tandai hadir", "+ Sesi tanpa jadwal").
KS-02 Intake QR (QR besar + daftar "baru masuk" + form verifikasi dalam bottom sheet).
KS-03 Daftar pasien.  KS-04 Tambah/edit pasien (form per bagian, nomor pasien baca-saja,
  contoh 1 inline error pada nomor HP, persetujuan data).
KS-05 Detail pasien versi kasir (kontak, paket, poin, tagihan belum lunas, jadwal).
KS-06 Buat jadwal (wizard: pasien → layanan → lokasi → terapis → SlotPicker dengan slot "Penuh").
KS-07 Booking masuk (kartu dengan Terima / Usulkan jam lain / Tolak).
KS-08 Pindah sesi massal (daftar sesi terdampak + pilih pengganti).
KS-09 Tagihan (tab Kasir dengan segmen Belum bayar/Menunggu/Belum lunas/Hari ini; detail tagihan
  dengan MoneyRow, urutan potongan member → voucher → manual → poin, UpsellCard emas).
KS-10 Pembayaran — buat 5 varian artboard: KS-10a Tunai (CashCalculator, kembalian besar),
  KS-10b QRIS (QR besar, hitung mundur 14:52, status Menunggu), KS-10c Transfer/VA,
  KS-10d Pakai paket (kuota sebelum/sesudah), KS-10e Gabungan (paket + tunai, sisa tagihan).
KS-11 Konfirmasi pembayaran & struk (centang besar, nominal, kembalian, kirim WA).
KS-12 Jual paket.  KS-13 Riwayat transaksi & detail.
KS-14 Refund (jenis, nominal, alasan, ringkasan dampak kuota/poin/komisi).
KS-15 Verifikasi transfer manual (foto bukti, Setujui/Tolak).
KS-16 Terima kas terapis.  KS-17 Tutup kas (sistem vs dihitung, selisih berwarna).
KS-18 Piutang (umur piutang, kirim link bayar).
```

### C.5 Modul Owner (OW-01 … OW-20)

```
Buat section "OW — Owner" berisi 20 artboard, tab bar Owner (tanpa FAB):
OW-01 Ringkasan (KpiTile omzet Rp38,4 jt +12%, grafik batang mingguan, % kembali, % slot,
  sesi per terapis, ActionAlert: 14 pasien belum kembali, 3 persetujuan).
OW-02 Jadwal semua terapis (kolom per terapis, geser horizontal).
OW-03 Pasien (seperti KS-03 + lintas cabang + aksi gabungkan data ganda).
OW-04 Laporan (daftar sub-laporan + satu contoh laporan omzet dengan grafik & tabel).
OW-05 Ekspor.  OW-06 Persetujuan (daftar per jenis dengan badge + satu detail refund).
OW-07 Rekap komisi.  OW-08 Kelola staf (daftar + form tambah).
OW-09 Layanan & harga.  OW-10 Paket & membership.  OW-11 Aturan komisi (dengan pratinjau hitungan).
OW-12 Voucher & promo.  OW-13 Aturan poin & referral.  OW-14 Template (tab treatment/area/WA,
  editor pesan WA dengan chip variabel {nama} {jam} dan pratinjau gelembung chat).
OW-15 Pustaka latihan.  OW-16 Pengumuman.  OW-17 Cabang & ruang.
OW-18 Audit log.  OW-19 Rekonsiliasi gateway.  OW-20 Kirim pengingat massal.
Untuk OW-06 s/d OW-19 tampilkan juga satu layar menu "Kelola" (dari Akun owner) yang menautkan semuanya.
```

### C.6 Modul Pasien (PS-01 … PS-20)

```
Buat section "PS — Pasien" berisi 20 artboard, tab bar Pasien. Nada ramah & menenangkan,
sapaan "Anda", hindari istilah klinis tanpa penjelasan:
PS-01 Onboarding (3 layar perkenalan dalam 1 artboard bergeser, cukup tampilkan layar 1 + titik).
PS-02 Masuk OTP (nomor HP → kotak 6 digit + kirim ulang 0:45).
PS-03 Hubungkan data lama (konfirmasi tanggal lahir).  PS-04 Persetujuan data.
PS-05 Beranda (progres pemulihan 72%, latihan hari ini, sesi berikutnya, poin emas,
  kartu tagihan belum lunas, "Booking ulang").
PS-06 Latihan (program aktif, centang hari ini).  PS-07 Detail latihan (video, langkah, catatan).
PS-08 Booking (wizard 4 langkah; tampilkan langkah SlotPicker dan ringkasan).
PS-09 Pembayaran online.  PS-10 Jadwal saya.  PS-11 Ubah/batalkan jadwal.
PS-12 Riwayat sesi (dengan gambar BodyMap & nyeri sebelum→sesudah).
PS-13 Paket & pembayaran.  PS-14 Beli paket.  PS-15 Struk.  PS-16 Poin & referral.
PS-17 Notifikasi.  PS-18 Profil (menu lengkap sesuai Lampiran A).  PS-19 Alamat tersimpan.
PS-20 Hapus akun.
```

### C.7 Halaman web & sistem feedback

```
Buat section "WB — Web" (artboard 390×844, tanpa tab bar, header sederhana logo One Lotus):
WB-01 Form intake via QR (field sesuai Lampiran A WB-01 + layar terima kasih dengan nomor antrian).
WB-02 Status pembayaran (berhasil / menunggu / gagal — 3 varian).
WB-03 Form booking website.

Lalu buat section "FB — Feedback" sebagai galeri komponen (§12):
toast sukses, toast error + "Coba lagi" + Ref kode, banner offline, banner peringatan medis,
bottom sheet duplicate_patient, dialog konfirmasi berisiko (Batalkan transaksi Rp450.000?),
inline error field, layar error penuh (sesi login berakhir), EmptyState, Skeleton,
SyncIndicator 4 status, StatusTag semua status sesi & pembayaran.
```

### C.8 Prompt revisi (pakai setelah semua modul jadi)

```
Periksa semua artboard terhadap aturan berikut dan perbaiki yang melanggar:
1) teks baca < 14 atau warna di luar token; 2) status hanya warna tanpa teks;
3) target sentuh < 48; 4) emas dipakai > 1 kali per layar; 5) tab bar tidak sesuai peran;
6) nama artboard tidak berawalan ID layar. Laporkan daftar perbaikan per ID.
```

### C.9 Prompt ikon, ilustrasi & animasi

```
Buat section "AS — Aset" di canvas yang sama, mengikuti Lampiran D:
1) Ikon: pakai Phosphor Icons saja (phosphoricons.com). Bobot regular untuk
   default, fill untuk tab aktif/terpilih, duotone untuk status berwarna.
   Tampilkan lembar 72 ikon D.1 dengan nama file One Lotus + nama Phosphor.
2) Ilustrasi: pakai unDraw (undraw.co) dengan warna aksen #0277B5; figur
   #1E3A4F; latar #E8F0F6. Kartu 320×240, label ID & layar pemakai (D.2).
3) Animasi: storyboard 3–5 frame tiap animasi D.3. Ikon animasi kecil dari
   useAnimations (CC BY, cantumkan atribusi), animasi bermerek dibuat khusus.
Lalu ganti ikon & placeholder ilustrasi di semua artboard dengan aset ini.
Gaya keseluruhan: latar #F2F5F8, kartu putih tanpa garis tepi radius 20 dengan
bayangan lembut, header "hero" biru tua #0B3B5C melengkung di layar beranda,
tombol 52dp radius 16, tab aktif berupa pil #E3F2FC di belakang ikon fill.
```

---

## Lampiran D — Ikon, ilustrasi & animasi

File siap pakai ada di paket `onelotus-assets` (SVG & Lottie JSON) beserta halaman pratinjau. Nama file = nama aset di Flutter (`assets/icons/`, `assets/illustrations/`, `assets/lottie/`). Semua aset berasal dari pustaka terbuka yang boleh dipakai komersial; lihat D.4 untuk kewajiban atribusi.

### D.0 Aturan umum

| Aspek | Ikon | Ilustrasi | Animasi |
|---|---|---|---|
| Sumber | Phosphor Icons v2 | unDraw | Khusus One Lotus + useAnimations |
| Format | SVG viewBox 256, `fill="currentColor"`, 3 file per ikon: `ic_x.svg` (regular), `ic_x_fill.svg`, `ic_x_duotone.svg` | SVG, rasio bebas, lebar tampil 160–260dp | Lottie JSON, 30–60 fps |
| Kapan bobot dipakai | regular = default · fill = tab aktif, chip/opsi terpilih · duotone = ikon status berwarna di kartu/banner | — | Khusus = momen bermerek · useAnimations = umpan balik kecil 24–48dp |
| Warna | Mengikuti teks (`fg`, `muted`, `brand`, status) | Sudah diwarnai: aksen `#0277B5`, figur `#1E3A4F`/`#16293A`, latar `#E8F0F6`/`#DCE7EF` | Sudah diwarnai per token status; bisa diganti via dynamic properties |
| Flutter | `flutter_svg` + `ColorFilter` dari tema | `flutter_svg`, `excludeFromSemantics: true` | `lottie`; saat "kurangi gerakan" tampilkan frame akhir |
| Aksesibilitas | Ikon tanpa label wajib `semanticLabel` | Dekoratif | Status juga ditulis sebagai teks |

### D.1 Inventori ikon (72 × 3 bobot)

Nama file One Lotus tetap sama dengan versi sebelumnya, sehingga kode tidak perlu berubah — hanya isi SVG yang diganti ke Phosphor. Pengelompokan:

- **Navigasi (14):** `ic_home` · `ic_calendar` · `ic_calendar_week` · `ic_calendar_plus` · `ic_users` · `ic_user` · `ic_history` · `ic_queue` · `ic_receipt` · `ic_chart` · `ic_report` · `ic_exercise` · `ic_grid` · `ic_plus`
- **Aksi (26):** `ic_search` · `ic_bell` · `ic_back` · `ic_chevron_right` · `ic_chevron_down` · `ic_close` · `ic_more` · `ic_edit` · `ic_archive` · `ic_filter` · `ic_sort` · `ic_share` · `ic_download` · `ic_upload` · `ic_camera` · `ic_mic` · `ic_attach` · `ic_send` · `ic_refresh` · `ic_copy` · `ic_phone` · `ic_chat` · `ic_print` · `ic_eye` · `ic_eye_off` · `ic_logout`
- **Status & sistem (14):** `ic_check` · `ic_check_circle` · `ic_alert` · `ic_info` · `ic_error` · `ic_clock` · `ic_lock` · `ic_fingerprint` · `ic_offline` · `ic_sync` · `ic_cloud_ok` · `ic_cloud_alert` · `ic_settings` · `ic_help`
- **Domain klinik (18):** `ic_body` · `ic_pain` · `ic_hands` · `ic_infrared` · `ic_stretch` · `ic_tape` · `ic_needle` · `ic_xray` · `ic_home_visit` · `ic_pin` · `ic_cash` · `ic_qris` · `ic_transfer` · `ic_package` · `ic_points` · `ic_voucher` · `ic_percent` · `ic_branch`

**Pemetaan ke nama Phosphor:** `home`→house · `calendar`→calendar-blank · `calendar_week`→calendar-dots · `calendar_plus`→calendar-plus · `users`→users · `user`→user · `history`→clock-counter-clockwise · `queue`→queue · `receipt`→receipt · `chart`→chart-bar · `report`→presentation-chart · `exercise`→barbell · `grid`→squares-four · `plus`→plus · `search`→magnifying-glass · `bell`→bell · `back`→caret-left · `chevron_right`→caret-right · `chevron_down`→caret-down · `close`→x · `more`→dots-three · `edit`→pencil-simple · `archive`→archive · `filter`→funnel-simple · `sort`→arrows-down-up · `share`→share-network · `download`→download-simple · `upload`→upload-simple · `camera`→camera · `mic`→microphone · `attach`→paperclip · `send`→paper-plane-tilt · `refresh`→arrow-clockwise · `copy`→copy · `phone`→phone · `chat`→chat-circle-dots · `print`→printer · `eye`→eye · `eye_off`→eye-slash · `logout`→sign-out · `check`→check · `check_circle`→check-circle · `alert`→warning · `info`→info · `error`→x-circle · `clock`→clock · `lock`→lock-simple · `fingerprint`→fingerprint · `offline`→cloud-slash · `sync`→arrows-clockwise · `cloud_ok`→cloud-check · `cloud_alert`→cloud-warning · `settings`→sliders-horizontal · `help`→question · `body`→person · `pain`→gauge · `hands`→hand · `infrared`→lamp · `stretch`→person-simple-tai-chi · `tape`→bandaids · `needle`→syringe · `xray`→scan · `home_visit`→house-line · `pin`→map-pin · `cash`→money · `qris`→qr-code · `transfer`→arrows-left-right · `package`→package · `points`→star · `voucher`→ticket · `percent`→percent · `branch`→buildings

> Logo merek pihak ketiga (WhatsApp, QRIS, bank, Play Store) **tidak** digambar ulang; pakai aset resmi pemilik merek atau ikon generik di atas (`ic_chat`, `ic_qris` = qr-code, `ic_transfer`).

### D.2 Inventori ilustrasi (20, unDraw)

| Nama file | Sumber unDraw | Dipakai di |
|---|---|---|
| `il_onboard_recovery` | unDraw · medicine | PS-01 (1/3) |
| `il_onboard_booking` | unDraw · booking | PS-01 (2/3) |
| `il_onboard_exercise` | unDraw · personal-trainer | PS-01 (3/3) |
| `il_empty_schedule` | unDraw · calendar | ST-01, TR-01/PS-10 kosong |
| `il_empty_search` | unDraw · searching | UM-10, TR-06, KS-03 tanpa hasil |
| `il_empty_inbox` | unDraw · my-notifications | UM-09, PS-17 kosong |
| `il_empty_exercise` | unDraw · meditation | PS-06 kosong |
| `il_empty_payment` | unDraw · done-checking | KS-09, KS-18 kosong |
| `il_success_payment` | unDraw · order-confirmed | KS-11, PS-09 berhasil |
| `il_offline` | unDraw · going-offline | ST-04, UM-01 offline |
| `il_maintenance` | unDraw · maintenance | UM-03 |
| `il_update` | unDraw · os-upgrade | UM-02 |
| `il_server_error` | unDraw · server-down | ST-03 |
| `il_session_locked` | unDraw · security-on | ST-15, UM-07 |
| `il_home_visit` | unDraw · my-current-location | TR-09 kosong |
| `il_thanks_intake` | unDraw · confirmed | WB-01 terima kasih |
| `il_login_staff` | unDraw · doctors | UM-04 (tablet / layar lebar) |
| `il_payment_online` | unDraw · pay-online | PS-09 header metode online |
| `il_reminder` | unDraw · reminder | PS-17 pengingat, opt-in notifikasi |
| `il_progress` | unDraw · progress-tracking | PS-12 progres pemulihan |

Sudah terpasang di prototipe: PS-01, UM-02, UM-03, KS-11, ST-01, ST-03, ST-15, WB-01.

### D.2b Peta tubuh (BodyMap, TR-04)

Sumber: **react-native-body-highlighter** (MIT, © ELABBASSI Hicham) — siluet anatomi depan & belakang dengan otot per area (deltoid, trapezius, upper-back, lower-back, quadriceps, hamstring, dll., kiri/kanan terpisah). Warna disesuaikan: dasar `#E3EBF2`, garis `#B7C7D4`, **ditangani** `#0277B5`, **penenang** `#F2B263`. File: `body/body_blank_front.svg`, `body/body_blank_back.svg`, contoh TR-04 `body/body_tr04_*.svg`, daftar area di `body/_parts.json`. Di Flutter pakai path yang sama di `CustomPainter`/`flutter_svg` dan petakan tiap `slug + sisi` ke area klinis (mis. `lower-back` → "Lumbal", `deltoids` kanan → "Bahu kanan"). Catatan: di tampak depan, sisi kanan pasien ada di kiri layar.

#### Interaksi & animasi BodyMap

Demo yang bisa diketuk: `body/bodymap-demo.html` (juga dipublikasikan sebagai halaman "Peta tubuh interaktif · TR-04").

| Momen | Gerak | Durasi · kurva | Flutter |
|---|---|---|---|
| Pilih otot | Warna isi dasar → warna mode (biru ditangani / oranye penenang) | 150ms · easeOut | `TweenAnimationBuilder<Color?>` per path |
| Konfirmasi ketuk | Skala 1 → 1,07 → 1 dari tengah otot | 320ms · `Cubic(.2,.8,.2,1)` | `AnimationController` + `Transform.scale` di bounds path |
| Hapus pilihan (ketuk lagi) | Warna kembali ke dasar | 150ms · easeOut | Sama, dibalik |
| Label area | Pil nama area (mis. "Bahu kanan") turun 6dp + muncul di atas siluet, hilang setelah 1,2 dtk | 150ms | `AnimatedOpacity` + `AnimatedSlide` |
| Chip masuk / keluar | Skala 0,85 ↔ 1 + fade | 200ms masuk · 150ms keluar | `AnimatedList` |
| Ketuk chip | Otot terkait berkedip sekali (opasitas 1 → 0,35 → 1) | 500ms · easeOut | `FadeTransition` |
| Haptic | Getar halus saat pilih/hapus | — | `HapticFeedback.selectionClick()` |
| Kurangi gerakan | Hanya warna berganti, tanpa denyut/kedip/geser | 0ms | `MediaQuery.disableAnimationsOf(context)` |

Aturan: otot yang sama di tampak depan & belakang (mis. bahu kanan) adalah satu area dan ikut tertandai di dua tampilan; kiri+kanan dengan mode sama digabung jadi satu chip "(kedua sisi)"; otot yang lebih kecil dari target ketuk 44dp dipilih lewat zoom atau daftar area.

### D.3 Inventori animasi (28)

**Lottie khusus One Lotus (12)** — momen bermerek
| Nama file | Gerak | Durasi | Loop | Dipakai di |
|---|---|---|---|---|
| `an_splash_lotus` | Kelopak lotus mekar dari tengah | 1,2 dtk | Tidak | UM-01 |
| `an_loading` | Tiga kelopak berputar bergantian | 1,0 dtk | Ya | Layar memuat > 1,5 dtk |
| `an_success` | Lingkaran terisi + centang tergambar | 0,8 dtk | Tidak | Simpan sesi |
| `an_error` | Lingkaran + silang + getar halus | 0,6 dtk | Tidak | Pembayaran gagal, layar error |
| `an_sync` | Dua panah melingkar berputar | 1,2 dtk | Ya | SyncIndicator, UM-14 |
| `an_qris_wait` | Bingkai QR berdenyut + titik berjalan | 1,6 dtk | Ya | QrisPanel menunggu |
| `an_payment_success` | Centang + 3 koin emas memantul | 1,2 dtk | Tidak | KS-11, PS-09 |
| `an_checkin` | Pin jatuh, memantul, riak | 0,9 dtk | Tidak | TR-09 check-in |
| `an_offline` | Awan berdenyut pelan | 2,0 dtk | Ya | Banner offline |
| `an_points` | Bintang muncul + percikan emas | 1,2 dtk | Tidak | PS-16, setelah bayar |
| `an_recording` | Lingkaran merah berdenyut | 1,0 dtk | Ya | Catatan suara TR-04 |
| `an_refresh` | Kelopak berputar mengikuti tarikan | 0,8 dtk | Ya | Tarik untuk refresh |

**Ikon animasi useAnimations (16)** — umpan balik kecil, warna sudah disesuaikan token
| Nama file | Sumber | Warna | Dipakai untuk |
|---|---|---|---|
| `an_ua_loading` | loading2 | #0277B5 | Memuat data / tombol loading |
| `an_ua_checkmark` | checkmark | #127A3E | Konfirmasi berhasil (toast, field valid) |
| `an_ua_alert` | alertCircle | #C0262D | Error inline / gagal simpan |
| `an_ua_warning` | alertTriangle | #9A4A07 | Peringatan (sinkron tertunda, kuota) |
| `an_ua_bell` | notification | #0277B5 | Lonceng notifikasi baru |
| `an_ua_lock` | lock | #0277B5 | Kunci layar / PIN / sesi berakhir |
| `an_ua_mic` | microphone2 | #C0262D | Rekam catatan suara terapis |
| `an_ua_calendar` | calendar | #0277B5 | Booking terkonfirmasi / ubah jadwal |
| `an_ua_star` | star | #A85E05 | Poin Lotus / rating sesi |
| `an_ua_download` | download | #0277B5 | Unduh struk / update aplikasi |
| `an_ua_checkbox` | checkBox | #127A3E | Centang latihan selesai |
| `an_ua_info` | info | #0277B5 | Tooltip / info harga |
| `an_ua_trash` | trash2 | #C0262D | Hapus draf / item |
| `an_ua_eye` | visibility | #0277B5 | Tampil/sembunyi password |
| `an_ua_heart` | heart | #C0262D | Feedback pasien / favorit |
| `an_ua_search` | searchToX | #0277B5 | Buka/tutup pencarian |

**Mikro-interaksi di kode (Flutter)**
| Interaksi | Spesifikasi |
|---|---|
| Pindah layar (push) | Geser dari kanan 24dp + fade, 220ms, `easeOutCubic` |
| Pindah tab | Fade silang 150ms, tanpa geser |
| Bottom sheet | Naik dari bawah 250ms `easeOutCubic`; scrim fade 200ms; turun 200ms `easeInCubic` |
| Dialog | Skala 0,96→1 + fade, 180ms |
| Toast | Naik 16dp + fade 200ms; hilang fade 150ms |
| Tekan tombol | Skala 0,98 selama ditekan, 100ms |
| Pilih chip / slot | Warna latar transisi 150ms + haptic selection |
| PainScale | Penanda bergeser 120ms per langkah + haptic selection |
| Centang checklist | Kotak terisi 150ms + garis centang trim 200ms |
| Skeleton | Shimmer kiri→kanan 1,2 dtk loop |
| Angka KPI / poin | Hitung naik 600ms `easeOutCubic` saat pertama tampil |
| Ring progres pasien | Terisi dari 0 ke nilai 800ms saat Beranda dibuka |
| Kurangi gerakan aktif | Semua di atas jadi fade ≤ 100ms; Lottie langsung ke frame akhir |

### D.4 Lisensi & atribusi

| Paket | Lisensi | Kewajiban di aplikasi |
|---|---|---|
| Phosphor Icons v2 (github.com/phosphor-icons/core) | MIT | Teks lisensi di halaman "Lisensi open source" |
| unDraw (undraw.co; diambil via github.com/balazser/undraw-svg-collection) | Lisensi unDraw: bebas komersial, tanpa atribusi | Tidak boleh dijual ulang/dibagikan sebagai paket ilustrasi |
| useAnimations (github.com/useAnimations/react-useanimations) | CC BY 4.0 | Tulis "Animations by useAnimations" di Tentang/Lisensi |
| react-native-body-highlighter (peta tubuh) | MIT | Teks lisensi di halaman "Lisensi open source" |
| Animasi khusus One Lotus | Milik proyek | — |
| `lottie` (Flutter) / lottie-web | MIT / Apache-2.0 | Otomatis lewat `showLicensePage` Flutter |

### D.5 Gaya visual v2 (dipakai di prototipe)

| Elemen | Spesifikasi |
|---|---|
| Latar layar | `#F2F5F8` |
| Kartu | Putih, tanpa garis tepi, radius 20, bayangan `0 1 2 /5%` + `0 6 20 -10 /14%` |
| Header beranda (hero) | `#0B3B5C`, sudut bawah radius 28, kartu pertama menumpuk 56dp ke dalam hero — TR-01, KS-01, OW-01, PS-05 |
| Kartu "sedang berjalan" | Gradien `#0277B5 → #0B4F7A`, teks putih, tombol putih |
| Judul layar | 24/800, letter-spacing −0,025em |
| Input | Latar putih, garis dalam 1,5px `#E4EBF1`, radius 14, fokus = garis brand 2px + ring `#E3F2FC` 4px |
| Tombol utama | Tinggi 52, radius 16, bayangan brand lembut |
| Tab bar | Putih 96%, ikon fill di dalam pil `#E3F2FC` saat aktif, label tebal |
| FAB | Lingkaran 56dp dengan cincin putih 6dp |
| Chip/slot terpilih | `#0B3B5C` teks putih |

---

*Catatan: nama pasien, terapis, alamat, dan angka pada mockup proposal adalah ilustrasi. Harga mengikuti pricelist One Lotus di website.*

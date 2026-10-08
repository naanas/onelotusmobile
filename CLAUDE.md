# One Lotus Mobile — konteks proyek

Aplikasi mobile untuk One Lotus Personal Therapy (Malang): staf (terapis, front desk/kasir, owner) + pasien.
Backend: sistem Laravel yang sudah ada, dinaikkan versinya dan dibuka sebagai REST API (Fase 0).

## Sumber kebenaran
- `docs/onelotus-mobile-ui-enhancement.md` — spesifikasi utama. Token desain §2, komponen §4, layar §5,
  alur end-to-end §6 (pembayaran §6.4), matriks akses §7, offline §8, aksesibilitas §9, privasi §10,
  microcopy §11 (staf pakai "kamu", pasien pakai "Anda"), feedback/popup/error §12, Definition of Done §14,
  katalog 90 layar Lampiran A, aset & animasi Lampiran D (termasuk BodyMap D.2b).
- `design/screens/<ID>.png` — tampilan final tiap layar (ID sama dengan Lampiran A). `_index.json` = daftar judul.
- `design/source/<ID>.html` — HTML statis tiap layar (buka di browser); `design/source/ol.css` = token & gaya v2.
- `design/bodymap-demo.html` — perilaku & animasi peta tubuh TR-04.
- `assets/` — ikon Phosphor (regular/fill/duotone), ilustrasi unDraw, Lottie, peta tubuh. Lisensi di `assets/README.md`.
- `docs/OneLotus-Mobile-Proposal-dan-UI.pdf` — proposal ke mitra + katalog UI.

## Keputusan yang sudah diambil
- **Satu aplikasi untuk staf & pasien** (diputuskan user, 8 Okt 2026; menggantikan rencana aplikasi pasien terpisah).
  Belum login → perkenalan pasien (PS-01) dengan tautan "Staf klinik? Masuk di sini"; staf menu sesuai peran,
  rute pasien berawalan `/pasien/` (`lib/pasien/`). Redirect gabungan: `appRedirect` di `lib/router/routes.dart`.
- Android dulu; iOS menyusul dari kode yang sama.
- Mode offline wajib untuk rekam sesi (Fase 1).

## Belum final
- Stack mobile: spec masih menulis Flutter; arah yang sedang dipertimbangkan Expo (React Native + TypeScript)
  karena dev memakai Mac Intel dan sudah familiar JS. Padanan: react-native-svg, lottie-react-native,
  phosphor-react-native, react-native-body-highlighter (sumber asli peta tubuh).
- 18 pertanyaan workshop di spec §16 belum dijawab mitra — jangan mengarang aturan komisi/paket/refund.

## Aturan kerja
- Ikuti layar di `design/screens` dan aturan di spec; jangan menambah pustaka ikon lain.
- Data di mockup (nama pasien, angka) hanyalah contoh.

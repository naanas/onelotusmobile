# One Lotus Mobile — Paket aset UI v2

Sesuai Lampiran D di `onelotus-mobile-ui-enhancement.md`. Semua aset dari pustaka terbuka yang boleh dipakai komersial.

| Folder | Isi | Sumber | Lisensi |
|---|---|---|---|
| `icons/` | 72 ikon × 3 bobot (`ic_x.svg` regular, `ic_x_fill.svg`, `ic_x_duotone.svg`) | Phosphor Icons v2 | MIT |
| `illustrations/` | 20 ilustrasi, sudah diwarnai palet One Lotus | unDraw | Lisensi unDraw (bebas komersial, tanpa atribusi) |
| `lottie/an_*.json` | 12 animasi khusus One Lotus | Dibuat untuk proyek ini | Milik proyek |
| `lottie/an_ua_*.json` | 16 ikon animasi, sudah diwarnai token status | useAnimations | CC BY 4.0 — wajib atribusi |
| `body/` | Peta tubuh depan/belakang (kosong + contoh TR-04) | react-native-body-highlighter | MIT |
| `preview.html` | Katalog semua aset (animasi bisa diputar, butuh internet untuk lottie-web) | — | — |

`icons/_index.json` berisi pemetaan nama One Lotus → nama Phosphor; `illustrations/_index.json` sumber unDraw; `lottie/_index.json` durasi, warna, dan kegunaan.

## Pakai di Flutter

```yaml
dependencies:
  flutter_svg: ^2.0.0
  lottie: ^3.0.0
flutter:
  assets:
    - assets/icons/
    - assets/illustrations/
    - assets/lottie/
```

```dart
// Ikon: regular default, _fill saat aktif
SvgPicture.asset(active ? 'assets/icons/ic_calendar_fill.svg' : 'assets/icons/ic_calendar.svg',
  width: 24, height: 24,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn), semanticsLabel: 'Jadwal');

SvgPicture.asset('assets/illustrations/il_empty_schedule.svg', width: 220, excludeFromSemantics: true);

final reduce = MediaQuery.of(context).disableAnimations;
Lottie.asset('assets/lottie/an_ua_checkmark.json', width: 32, repeat: false, animate: !reduce);
```

Alternatif ikon: paket `phosphor_flutter` di pub.dev memuat set Phosphor yang sama (pemetaan nama ada di `icons/_index.json`).

## Atribusi yang wajib dicantumkan di aplikasi (halaman Tentang/Lisensi)

- Icons: Phosphor Icons — MIT License, © Phosphor Icons
- Animations by useAnimations — CC BY 4.0
- Body map: react-native-body-highlighter — MIT License, © ELABBASSI Hicham
- Illustrations: unDraw (tidak wajib, tapi disarankan)

## Catatan

- Logo merek pihak ketiga (WhatsApp, QRIS, bank) tidak disertakan; pakai aset resmi masing-masing atau ikon generik `ic_chat`, `ic_qris`, `ic_transfer`.
- Semua animasi sudah diuji render dengan lottie-web. Uji sekali di perangkat Flutter sebelum rilis.

## Font

`fonts/` — Plus Jakarta Sans (400–800) & JetBrains Mono (500, 700), subset latin dari Fontsource. Lisensi SIL Open Font License 1.1.

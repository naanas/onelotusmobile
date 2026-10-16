# One Lotus Mobile

Satu aplikasi Flutter untuk staf (terapis, kasir, owner) dan pasien One Lotus. Semua data diambil dari
One Lotus API (`../backend`); aplikasi tidak punya mode data contoh.

## Menjalankan (dev)

1. Jalankan backend: `cd ../backend && go run ./cmd/server` (set `MOBILE_OTP_DEV_LOG=true` di `.env`
   agar kode OTP pasien tampil di log server).
2. Salin `env/dev.example.json` ke `env/dev.json`, isi `API_URL` dengan IP laptop
   (`ipconfig getifaddr en0`), mis. `http://192.168.1.10:8080`. Emulator Android: `http://10.0.2.2:8080`.
   HP dan laptop harus di Wi-Fi yang sama.
3. Jalankan aplikasi:

   ```
   flutter run --dart-define-from-file=env/dev.json
   ```

   Di VS Code cukup pilih konfigurasi **One Lotus (dev, backend laptop)** lalu Run.

## Memakai backend Render

`env/prod.json` berisi alamat API yang sudah di-deploy (salin dari `env/prod.example.json`):

```
flutter run --dart-define-from-file=env/prod.json                    # HP tersambung, debug
flutter build apk --release --dart-define-from-file=env/prod.json    # APK untuk dibagikan
```

Di VS Code: konfigurasi **One Lotus (Render)**. Instance gratis Render tidur bila lama tak dipakai;
permintaan pertama sesudahnya bisa > 50 detik sehingga aplikasi menampilkan error koneksi — coba lagi.

Nilai `API_URL` ditanam saat build: setelah mengubahnya, hentikan lalu `flutter run` lagi (hot reload tidak cukup).
`env/*.json` tidak masuk git, kecuali `*.example.json`.

## Tes

```
flutter analyze
flutter test
flutter test test/contract --dart-define=LIVE_API=http://localhost:8080 --dart-define=OTP_LOG=/path/server.log
```

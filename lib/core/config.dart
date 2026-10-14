/// Konfigurasi build. Wajib: `flutter run --dart-define-from-file=env/dev.json` (isi `API_URL`,
/// lihat `env/dev.example.json`; rilis: alamat HTTPS API). Tanpa API_URL aplikasi menampilkan layar konfigurasi.
abstract final class AppConfig {
  static const apiUrl = String.fromEnvironment('API_URL');
  static bool get configured => apiUrl.isNotEmpty;

  /// Request > 15 dtk dianggap `network_timeout` (§12.4).
  static const requestTimeout = Duration(seconds: 15);
}

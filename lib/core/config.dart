/// Konfigurasi build. `flutter run --dart-define=API_URL=https://api.onelotus.id`
/// Kosong = mode mock (data contoh di HP, tanpa server).
abstract final class AppConfig {
  static const apiUrl = String.fromEnvironment('API_URL');
  static bool get useMock => apiUrl.isEmpty;

  /// Request > 15 dtk dianggap `network_timeout` (§12.4).
  static const requestTimeout = Duration(seconds: 15);
}

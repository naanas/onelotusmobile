import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

/// Biometrik & izin perangkat, dibungkus agar bisa diganti di tes.
abstract interface class DeviceSecurity {
  Future<bool> biometricAvailable();
  Future<bool> authenticateBiometric(String reason);
  Future<bool> requestNotificationPermission();
}

class PlatformDeviceSecurity implements DeviceSecurity {
  final _auth = LocalAuthentication();

  @override
  Future<bool> biometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async =>
      (await Permission.notification.request()).isGranted;
}

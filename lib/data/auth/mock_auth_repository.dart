import '../models/staff_user.dart';
import 'auth_repository.dart';

/// Data contoh — nama & cabang mengikuti mockup, bukan data asli.
abstract final class MockBranches {
  static const pusat = Branch(
    id: 'pusat',
    name: 'Klinik Pusat Malang',
    address: 'Jl. Soekarno-Hatta, Lowokwaru',
  );
  static const batu = Branch(
    id: 'batu',
    name: 'Cabang Batu',
    address: 'Jl. Diponegoro, Batu',
  );
}

class _MockAccount {
  _MockAccount(this.user, this.password, {this.active = true});
  StaffUser user;
  String password;
  final bool active;
}

/// Akun contoh untuk mode mock (API_URL kosong).
///
/// | username        | password    | catatan                                   |
/// |-----------------|-------------|-------------------------------------------|
/// | dimas.terapis   | terapis123  | terapis + kasir, 2 cabang → UM-08         |
/// | sinta.kasir     | kasir123    | kasir, 1 cabang                           |
/// | rudi.owner      | owner123    | owner + terapis (pengalih peran)          |
/// | baru.terapis    | sementara1  | password sementara → UM-05 login pertama  |
/// | lama.kasir      | kasir123    | akun nonaktif                             |
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 600)});

  final Duration latency;

  final _accounts = <String, _MockAccount>{
    'dimas.terapis': _MockAccount(
      const StaffUser(
        id: 'u1',
        username: 'dimas.terapis',
        name: 'Dimas Prasetyo',
        roles: [Role.terapis, Role.kasir],
        branches: [MockBranches.pusat, MockBranches.batu],
      ),
      'terapis123',
    ),
    'sinta.kasir': _MockAccount(
      const StaffUser(
        id: 'u2',
        username: 'sinta.kasir',
        name: 'Sinta Maharani',
        roles: [Role.kasir],
        branches: [MockBranches.pusat],
      ),
      'kasir123',
    ),
    'rudi.owner': _MockAccount(
      const StaffUser(
        id: 'u3',
        username: 'rudi.owner',
        name: 'Rudi Hartanto',
        roles: [Role.owner, Role.terapis],
        branches: [MockBranches.pusat],
      ),
      'owner123',
    ),
    'baru.terapis': _MockAccount(
      const StaffUser(
        id: 'u4',
        username: 'baru.terapis',
        name: 'Laras Ayuningtyas',
        roles: [Role.terapis],
        branches: [MockBranches.pusat],
        mustChangePassword: true,
      ),
      'sementara1',
    ),
    'lama.kasir': _MockAccount(
      const StaffUser(
        id: 'u5',
        username: 'lama.kasir',
        name: 'Akun Lama',
        roles: [Role.kasir],
        branches: [MockBranches.pusat],
      ),
      'kasir123',
      active: false,
    ),
  };

  final _tokens = <String, String>{}; // token → username

  Future<void> _wait() => Future<void>.delayed(latency);

  @override
  Future<AppStatus> appStatus() async {
    await _wait();
    return const AppStatus();
  }

  @override
  Future<LoginSuccess> login(String username, String password) async {
    await _wait();
    final acc = _accounts[username.trim().toLowerCase()];
    if (acc == null || acc.password != password) {
      throw const LoginException(LoginFailure.invalidCredentials);
    }
    if (!acc.active) throw const LoginException(LoginFailure.accountDisabled);
    final token =
        'mock-${acc.user.id}-${DateTime.now().millisecondsSinceEpoch}';
    _tokens[token] = acc.user.username;
    return LoginSuccess(token: token, user: acc.user);
  }

  @override
  Future<void> changePassword(
    String token, {
    required String current,
    required String next,
  }) async {
    await _wait();
    final acc = _accounts[_tokens[token]];
    if (acc == null) return; // token mock dari sesi lama — anggap berhasil
    if (acc.password != current) {
      throw const LoginException(LoginFailure.invalidCredentials);
    }
    acc
      ..password = next
      ..user = acc.user.copyWith(mustChangePassword: false);
  }

  @override
  Future<void> requestPasswordReset(String username, {String? note}) => _wait();

  @override
  Future<void> logout(String token) async {
    _tokens.remove(token);
  }
}

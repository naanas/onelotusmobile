/// Peran staf (§3, A.1). Pasien ada di aplikasi terpisah (Fase 3).
enum Role {
  terapis('terapis', 'Terapis', 'Jadwal, rekam sesi, home visit'),
  kasir('kasir', 'Kasir / front desk', 'Antrian, tagihan, pembayaran'),
  owner('owner', 'Owner', 'Ringkasan, laporan, persetujuan');

  const Role(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static Role? fromId(String? id) =>
      Role.values.where((r) => r.id == id).firstOrNull;
}

class Branch {
  const Branch({required this.id, required this.name, required this.address});

  final String id;
  final String name;
  final String address;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'address': address};

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
    id: j['id'] as String,
    name: j['name'] as String,
    address: j['address'] as String,
  );

  @override
  bool operator ==(Object other) => other is Branch && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class StaffUser {
  const StaffUser({
    required this.id,
    required this.username,
    required this.name,
    required this.roles,
    required this.branches,
    this.mustChangePassword = false,
  });

  final String id;
  final String username;
  final String name;
  final List<Role> roles;
  final List<Branch> branches;

  /// Akun memakai password sementara → wajib lewat UM-05.
  final bool mustChangePassword;

  String get firstName => name.split(' ').first;

  /// Perlu memilih di UM-08 bila punya lebih dari satu peran atau cabang.
  bool get needsContextChoice => roles.length > 1 || branches.length > 1;

  StaffUser copyWith({bool? mustChangePassword}) => StaffUser(
    id: id,
    username: username,
    name: name,
    roles: roles,
    branches: branches,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'roles': [for (final r in roles) r.id],
    'branches': [for (final b in branches) b.toJson()],
    'mustChangePassword': mustChangePassword,
  };

  factory StaffUser.fromJson(Map<String, dynamic> j) => StaffUser(
    id: j['id'] as String,
    username: j['username'] as String,
    name: j['name'] as String,
    roles: [for (final r in j['roles'] as List) ?Role.fromId(r as String)],
    branches: [
      for (final b in j['branches'] as List)
        Branch.fromJson(b as Map<String, dynamic>),
    ],
    mustChangePassword: j['mustChangePassword'] as bool? ?? false,
  );
}

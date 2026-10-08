import 'json.dart';

/// Layanan dari pricelist per cabang. Harga dalam rupiah (bilangan bulat).
/// Biaya per titik, tambahan cedera, harga member: menunggu aturan dari workshop (§16).
class Service {
  const Service({
    required this.id,
    required this.name,
    required this.durationMin,
    required this.price,
  });

  final String id;
  final String name;
  final int durationMin;
  final int price;

  factory Service.fromJson(Map<String, dynamic> j) => Service(
    id: j['id'].toString(),
    name: j['name'] as String,
    durationMin: parseInt(j['duration_min']) ?? 0,
    price: parseInt(j['price']) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'duration_min': durationMin,
    'price': price,
  };
}

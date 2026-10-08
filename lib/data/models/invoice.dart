import 'json.dart';
import 'status.dart';

class InvoiceItem {
  const InvoiceItem({required this.label, required this.amount});

  final String label;

  /// Rupiah.
  final int amount;

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
    label: j['label'] as String,
    amount: parseInt(j['amount']) ?? 0,
  );

  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};
}

/// Urutan potongan transparan di MoneyRow (§6.4.4): member → voucher → manual → poin.
enum AdjustmentKind { member, voucher, manual, points }

class InvoiceAdjustment {
  const InvoiceAdjustment({
    required this.kind,
    required this.label,
    required this.amount,
    this.reason,
  });

  final AdjustmentKind kind;
  final String label;

  /// Nilai potongan (positif = mengurangi tagihan).
  final int amount;

  /// Diskon manual wajib alasan (§6.4.4).
  final String? reason;

  factory InvoiceAdjustment.fromJson(Map<String, dynamic> j) =>
      InvoiceAdjustment(
        kind: AdjustmentKind.values.byName(j['kind'] as String),
        label: j['label'] as String,
        amount: parseInt(j['amount']) ?? 0,
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'label': label,
    'amount': amount,
    'reason': reason,
  };
}

/// Tagihan (§6.4). Total dihitung server; [computedTotal] hanya untuk tampilan offline.
class Invoice {
  const Invoice({
    required this.id,
    required this.sessionId,
    required this.patientId,
    required this.items,
    required this.status,
    this.adjustments = const [],
    this.total,
    this.paidAmount = 0,
    this.paidAt,
  });

  final String id;
  final String sessionId;
  final String patientId;
  final List<InvoiceItem> items;
  final List<InvoiceAdjustment> adjustments;
  final PaymentStatus status;

  /// Total dari server (sumber kebenaran).
  final int? total;
  final int paidAmount;
  final DateTime? paidAt;

  int get subtotal => items.fold(0, (s, i) => s + i.amount);

  int get computedTotal {
    final sorted = [...adjustments]
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    final t = sorted.fold(subtotal, (s, a) => s - a.amount);
    return t < 0 ? 0 : t;
  }

  int get grandTotal => total ?? computedTotal;

  /// Sisa untuk status "Belum lunas" (§6.4.1).
  int get remaining => (grandTotal - paidAmount).clamp(0, grandTotal);

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    id: j['id'].toString(),
    sessionId: j['session_id'].toString(),
    patientId: j['patient_id'].toString(),
    items: [
      for (final i in (j['items'] as List?) ?? const [])
        InvoiceItem.fromJson(i as Map<String, dynamic>),
    ],
    adjustments: [
      for (final a in (j['adjustments'] as List?) ?? const [])
        InvoiceAdjustment.fromJson(a as Map<String, dynamic>),
    ],
    status: PaymentStatus.fromApi(j['status'] as String?),
    total: parseInt(j['total']),
    paidAmount: parseInt(j['paid_amount']) ?? 0,
    paidAt: parseDate(j['paid_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'patient_id': patientId,
    'items': [for (final i in items) i.toJson()],
    'adjustments': [for (final a in adjustments) a.toJson()],
    'status': status.api,
    'total': total,
    'paid_amount': paidAmount,
    'paid_at': formatDate(paidAt),
  };
}

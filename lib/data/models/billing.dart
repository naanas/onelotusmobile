import 'json.dart';

/// Model fase 2 (tagihan, pembayaran, kas, komisi, laporan, pengaturan owner) — bentuk JSON One Lotus API v1.

Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};
List<Map<String, dynamic>> _l(Object? v) => [for (final e in (v as List?) ?? const []) _m(e)];

class InvItem {
  const InvItem({required this.kind, required this.description, required this.qty, required this.unitPrice, required this.amount, this.serviceId});
  final String kind;
  final String description;
  final int qty;
  final int unitPrice;
  final int amount;
  final String? serviceId;

  factory InvItem.fromJson(Map<String, dynamic> j) => InvItem(
    kind: j['kind'] as String? ?? 'service',
    description: j['description'] as String? ?? '',
    qty: parseInt(j['qty']) ?? 1,
    unitPrice: parseInt(j['unit_price']) ?? 0,
    amount: parseInt(j['amount']) ?? 0,
    serviceId: j['service_id']?.toString(),
  );
}

class PaymentV {
  const PaymentV({
    required this.id,
    required this.method,
    required this.amount,
    required this.status,
    this.invoiceId,
    this.cashReceived,
    this.changeGiven,
    this.qrString,
    this.vaBank,
    this.vaNumber,
    this.paymentUrl,
    this.expiresAt,
    this.collectorName,
    this.paidAt,
    this.createdAt,
  });
  final String id;
  final String? invoiceId;
  final String method;
  final int amount;
  final String status;
  final int? cashReceived;
  final int? changeGiven;
  final String? qrString;
  final String? vaBank;
  final String? vaNumber;
  final String? paymentUrl;
  final DateTime? expiresAt;
  final String? collectorName;
  final DateTime? paidAt;
  final DateTime? createdAt;

  bool get pending => status == 'pending' || status == 'awaiting_verification';

  factory PaymentV.fromJson(Map<String, dynamic> j) => PaymentV(
    id: j['id'].toString(),
    invoiceId: j['invoice_id']?.toString(),
    method: j['method'] as String? ?? '',
    amount: parseInt(j['amount']) ?? 0,
    status: j['status'] as String? ?? '',
    cashReceived: parseInt(j['cash_received']),
    changeGiven: parseInt(j['change_given']),
    qrString: j['qr_string'] as String?,
    vaBank: j['va_bank'] as String?,
    vaNumber: j['va_number'] as String?,
    paymentUrl: j['payment_url'] as String?,
    expiresAt: parseDate(j['expires_at']),
    collectorName: _m(j['collected_by'])['name'] as String?,
    paidAt: parseDate(j['paid_at']),
    createdAt: parseDate(j['created_at']),
  );
}

const paymentMethodLabels = {
  'cash': 'Tunai',
  'qris': 'QRIS',
  'va': 'Virtual account',
  'transfer_manual': 'Transfer manual',
  'package': 'Paket',
  'points': 'Poin',
  'payment_link': 'Link bayar',
  'ewallet': 'E-wallet',
};

const invoiceStatusLabels = {
  'draft': 'Draft',
  'unpaid': 'Belum bayar',
  'awaiting_payment': 'Menunggu pembayaran',
  'partially_paid': 'Belum lunas',
  'paid': 'Lunas',
  'cancelled': 'Dibatalkan',
  'partially_refunded': 'Refund sebagian',
  'refunded': 'Refund penuh',
};

class InvoiceV {
  const InvoiceV({
    required this.id,
    required this.kind,
    required this.status,
    required this.items,
    required this.payments,
    required this.version,
    this.number,
    this.patientId,
    this.patientName = '',
    this.patientNumber = 0,
    this.sessionId,
    this.sessionDate,
    this.therapistName,
    this.subtotal = 0,
    this.memberDiscount = 0,
    this.voucherCode,
    this.voucherDiscount = 0,
    this.manualDiscount = 0,
    this.manualDiscountStatus = 'none',
    this.pointsUsed = 0,
    this.pointsDiscount = 0,
    this.total = 0,
    this.paid = 0,
    this.refunded = 0,
    this.balance = 0,
    this.receiptId,
    this.issuedAt,
    this.paidAt,
  });

  final String id;
  final String? number;
  final String kind;
  final String status;
  final String? patientId;
  final String patientName;
  final int patientNumber;
  final String? sessionId;
  final DateTime? sessionDate;
  final String? therapistName;
  final List<InvItem> items;
  final List<PaymentV> payments;
  final int subtotal, memberDiscount, voucherDiscount, manualDiscount, pointsDiscount, total, paid, refunded, balance;
  final String? voucherCode;
  final String manualDiscountStatus;
  final int pointsUsed;
  final String? receiptId;
  final DateTime? issuedAt;
  final DateTime? paidAt;
  final int version;

  String get statusLabel => invoiceStatusLabels[status] ?? status;
  bool get payable => const {'draft', 'unpaid', 'partially_paid', 'awaiting_payment'}.contains(status) && balance > 0;
  bool get refundable => const {'paid', 'partially_paid', 'partially_refunded'}.contains(status) && paid > refunded;
  PaymentV? get pendingPayment => payments.where((p) => p.pending).firstOrNull;

  factory InvoiceV.fromJson(Map<String, dynamic> j) {
    final b = _m(j['breakdown']);
    final p = _m(j['patient']);
    final s = _m(j['session']);
    return InvoiceV(
      id: j['id'].toString(),
      number: j['number'] as String?,
      kind: j['kind'] as String? ?? 'session',
      status: j['status'] as String? ?? 'draft',
      patientId: p['id']?.toString(),
      patientName: p['name'] as String? ?? '',
      patientNumber: parseInt(p['number']) ?? 0,
      sessionId: s['id']?.toString(),
      sessionDate: parseDate(s['date']),
      therapistName: s['therapist_name'] as String?,
      items: [for (final i in _l(j['items'])) InvItem.fromJson(i)],
      payments: [for (final y in _l(j['payments'])) PaymentV.fromJson(y)],
      subtotal: parseInt(b['subtotal']) ?? 0,
      memberDiscount: parseInt(b['member_discount']) ?? 0,
      voucherCode: b['voucher_code'] as String?,
      voucherDiscount: parseInt(b['voucher_discount']) ?? 0,
      manualDiscount: parseInt(b['manual_discount']) ?? 0,
      manualDiscountStatus: b['manual_discount_status'] as String? ?? 'none',
      pointsUsed: parseInt(b['points_used']) ?? 0,
      pointsDiscount: parseInt(b['points_discount']) ?? 0,
      total: parseInt(b['total']) ?? 0,
      paid: parseInt(b['paid']) ?? 0,
      refunded: parseInt(b['refunded']) ?? 0,
      balance: parseInt(b['balance']) ?? 0,
      receiptId: j['receipt_id']?.toString(),
      issuedAt: parseDate(j['issued_at']),
      paidAt: parseDate(j['paid_at']),
      version: parseInt(j['version']) ?? 0,
    );
  }
}

class PaymentResult {
  const PaymentResult({required this.payment, required this.invoice, this.receipt});
  final PaymentV payment;
  final InvoiceV invoice;
  final ReceiptV? receipt;

  factory PaymentResult.fromJson(Map<String, dynamic> j) => PaymentResult(
    payment: PaymentV.fromJson(_m(j['payment'])),
    invoice: InvoiceV.fromJson(_m(j['invoice'])),
    receipt: j['receipt'] is Map ? ReceiptV.fromJson(_m(j['receipt'])) : null,
  );
}

class ReceiptV {
  const ReceiptV({
    required this.id,
    required this.number,
    required this.issuedAt,
    required this.items,
    required this.breakdown,
    required this.payments,
    this.branchName = '',
    this.branchAddress = '',
    this.patientName = '',
    this.patientNumber = 0,
    this.therapistName,
    this.changeGiven,
    this.packageRemaining,
    this.pointsEarned = 0,
    this.collectedBy = '',
    this.lastSentAt,
  });
  final String id, number;
  final DateTime issuedAt;
  final String branchName, branchAddress, patientName, collectedBy;
  final int patientNumber, pointsEarned;
  final String? therapistName;
  final List<InvItem> items;
  final Map<String, dynamic> breakdown;
  final List<({String method, int amount, String? ref})> payments;
  final int? changeGiven, packageRemaining;
  final DateTime? lastSentAt;

  factory ReceiptV.fromJson(Map<String, dynamic> j) => ReceiptV(
    id: j['id'].toString(),
    number: j['number'] as String? ?? '',
    issuedAt: parseDate(j['issued_at']) ?? DateTime.now(),
    branchName: _m(j['branch'])['name'] as String? ?? '',
    branchAddress: _m(j['branch'])['address'] as String? ?? '',
    patientName: _m(j['patient'])['name'] as String? ?? '',
    patientNumber: parseInt(_m(j['patient'])['number']) ?? 0,
    therapistName: j['therapist_name'] as String?,
    items: [for (final i in _l(j['items'])) InvItem.fromJson(i)],
    breakdown: _m(j['breakdown']),
    payments: [
      for (final y in _l(j['payments']))
        (method: y['method'] as String? ?? '', amount: parseInt(y['amount']) ?? 0, ref: y['ref'] as String?),
    ],
    changeGiven: parseInt(j['change_given']),
    packageRemaining: parseInt(j['package_remaining']),
    pointsEarned: parseInt(j['points_earned']) ?? 0,
    collectedBy: j['collected_by'] as String? ?? '',
    lastSentAt: parseDate(j['last_sent_at']),
  );
}

class OwnershipV {
  const OwnershipV({required this.id, required this.name, required this.remaining, required this.total, required this.status, this.expiresOn});
  final String id, name, status;
  final int remaining, total;
  final DateTime? expiresOn;

  factory OwnershipV.fromJson(Map<String, dynamic> j) => OwnershipV(
    id: j['id'].toString(),
    name: _m(j['package'])['name'] as String? ?? 'Paket',
    remaining: parseInt(j['remaining']) ?? 0,
    total: parseInt(j['sessions_total']) ?? 0,
    status: j['status'] as String? ?? '',
    expiresOn: parseDate(j['expires_on']),
  );
}

class PackageV {
  const PackageV({
    required this.id,
    required this.name,
    required this.sessionCount,
    required this.validDays,
    required this.price,
    this.savings = 0,
    this.serviceIds = const [],
    this.branchIds = const [],
    this.isActive = true,
  });
  final String id, name;
  final int sessionCount, validDays, price, savings;
  final List<String> serviceIds, branchIds;
  final bool isActive;

  factory PackageV.fromJson(Map<String, dynamic> j) => PackageV(
    id: j['id'].toString(),
    name: j['name'] as String? ?? '',
    sessionCount: parseInt(j['session_count']) ?? 0,
    validDays: parseInt(j['valid_days']) ?? 0,
    price: parseInt(j['price']) ?? 0,
    savings: parseInt(j['savings_vs_single']) ?? 0,
    serviceIds: parseStrings(j['service_ids']),
    branchIds: parseStrings(j['branch_ids']),
    isActive: j['is_active'] as bool? ?? true,
  );
}

class PointsSummaryV {
  const PointsSummaryV({required this.balance, this.valueRupiah = 0, this.history = const [], this.referralCode, this.referrals = 0, this.expiring = const []});
  final int balance, valueRupiah, referrals;
  final String? referralCode;
  final List<({int delta, String reason, DateTime? at})> history;
  final List<({int points, DateTime? at})> expiring;

  factory PointsSummaryV.fromJson(Map<String, dynamic> j) => PointsSummaryV(
    balance: parseInt(j['balance']) ?? 0,
    valueRupiah: parseInt(j['value_rupiah']) ?? 0,
    referralCode: j['referral_code'] as String?,
    referrals: parseInt(j['referrals_rewarded']) ?? 0,
    history: [for (final h in _l(j['history'])) (delta: parseInt(h['delta']) ?? 0, reason: h['reason'] as String? ?? '', at: parseDate(h['at']))],
    expiring: [for (final e in _l(j['expiring'])) (points: parseInt(e['points']) ?? 0, at: parseDate(e['expires_at']))],
  );
}

class RefundV {
  const RefundV({required this.id, required this.amount, required this.status, this.method, this.kind, this.impact = const {}, this.createdAt});
  final String id, status;
  final int amount;
  final String? method, kind;
  final Map<String, dynamic> impact;
  final DateTime? createdAt;

  factory RefundV.fromJson(Map<String, dynamic> j) => RefundV(
    id: j['id'].toString(),
    amount: parseInt(j['amount']) ?? 0,
    status: j['status'] as String? ?? '',
    method: j['method'] as String?,
    kind: j['kind'] as String?,
    impact: _m(j['impact']),
    createdAt: parseDate(j['created_at']),
  );
}

class ReceivableV {
  const ReceivableV({required this.invoiceId, required this.balance, required this.ageDays, required this.patientName, this.patientNumber = 0, this.lastRemindedAt});
  final String invoiceId, patientName;
  final int balance, ageDays, patientNumber;
  final DateTime? lastRemindedAt;

  factory ReceivableV.fromJson(Map<String, dynamic> j) => ReceivableV(
    invoiceId: j['invoice_id'].toString(),
    balance: parseInt(j['balance']) ?? 0,
    ageDays: parseInt(j['age_days']) ?? 0,
    patientName: _m(j['patient'])['name'] as String? ?? '',
    patientNumber: parseInt(_m(j['patient'])['number']) ?? 0,
    lastRemindedAt: parseDate(j['last_reminded_at']),
  );
}

// ---- kas ----

class CashCarriedV {
  const CashCarriedV({required this.date, required this.total, required this.status, required this.transactions, this.handoverId});
  final DateTime date;
  final int total;
  final String status;
  final String? handoverId;
  final List<({String patientName, int amount, DateTime? at})> transactions;

  factory CashCarriedV.fromJson(Map<String, dynamic> j) => CashCarriedV(
    date: DateTime.parse(j['date'] as String),
    total: parseInt(j['total']) ?? 0,
    status: j['status'] as String? ?? 'carried',
    handoverId: j['handover_id']?.toString(),
    transactions: [
      for (final t in _l(j['transactions']))
        (patientName: t['patient_name'] as String? ?? '', amount: parseInt(t['amount']) ?? 0, at: parseDate(t['at'])),
    ],
  );
}

class HandoverV {
  const HandoverV({required this.id, required this.amountExpected, required this.status, this.therapistName = '', this.amountReceived, this.businessDate, this.note});
  final String id, status, therapistName;
  final int amountExpected;
  final int? amountReceived;
  final DateTime? businessDate;
  final String? note;

  factory HandoverV.fromJson(Map<String, dynamic> j) => HandoverV(
    id: j['id'].toString(),
    amountExpected: parseInt(j['amount_expected']) ?? 0,
    amountReceived: parseInt(j['amount_received']),
    status: j['status'] as String? ?? '',
    therapistName: _m(j['therapist'])['name'] as String? ?? '',
    businessDate: j['business_date'] == null ? null : DateTime.tryParse(j['business_date'] as String),
    note: j['note'] as String?,
  );
}

class ClosingPreviewV {
  const ClosingPreviewV({required this.date, required this.expected, required this.canClose, this.blocking, this.therapistCash = const [], this.openGateway = const []});
  final DateTime date;
  final Map<String, int> expected;
  final bool canClose;
  final String? blocking;
  final List<HandoverV> therapistCash;
  final List<PaymentV> openGateway;

  factory ClosingPreviewV.fromJson(Map<String, dynamic> j) => ClosingPreviewV(
    date: DateTime.parse(j['business_date'] as String),
    expected: {for (final e in _m(j['expected']).entries) e.key: parseInt(e.value) ?? 0},
    canClose: j['can_close'] as bool? ?? false,
    blocking: j['blocking_reason'] as String?,
    therapistCash: [for (final h in _l(j['therapist_cash'])) HandoverV.fromJson(h)],
    openGateway: [for (final y in _l(j['open_gateway_payments'])) PaymentV.fromJson(y)],
  );
}

// ---- komisi ----

class CommissionV {
  const CommissionV({required this.id, required this.amount, required this.status, this.date, this.patientInitials = '', this.label = '', this.isCorrection = false});
  final String id, status, patientInitials, label;
  final int amount;
  final DateTime? date;
  final bool isCorrection;

  factory CommissionV.fromJson(Map<String, dynamic> j) => CommissionV(
    id: j['id'].toString(),
    amount: parseInt(j['amount']) ?? 0,
    status: j['status'] as String? ?? '',
    date: j['date'] == null ? null : DateTime.tryParse(j['date'] as String),
    patientInitials: j['patient_initials'] as String? ?? '',
    label: j['service_name'] as String? ?? '',
    isCorrection: j['is_correction'] as bool? ?? false,
  );
}

class CommissionSummaryV {
  const CommissionSummaryV({required this.period, required this.total, required this.status, this.staffId, this.staffName = '', this.sessions = 0, this.homeVisits = 0, this.adjustments = 0, this.items = const []});
  final String period, status, staffName;
  final String? staffId;
  final int total, sessions, homeVisits, adjustments;
  final List<CommissionV> items;

  factory CommissionSummaryV.fromJson(Map<String, dynamic> j) => CommissionSummaryV(
    period: j['period'] as String? ?? '',
    total: parseInt(j['total']) ?? 0,
    status: j['status'] as String? ?? 'estimated',
    staffId: _m(j['staff'])['id']?.toString(),
    staffName: _m(j['staff'])['name'] as String? ?? '',
    sessions: parseInt(j['sessions']) ?? 0,
    homeVisits: parseInt(j['home_visits']) ?? 0,
    adjustments: parseInt(j['adjustments']) ?? 0,
    items: [for (final i in _l(j['items'])) CommissionV.fromJson(i)],
  );
}

const commissionStatusLabels = {'estimated': 'Estimasi', 'approved': 'Disetujui', 'paid': 'Dibayar'};

class CommissionRuleV {
  const CommissionRuleV({required this.id, required this.scope, required this.type, required this.value, required this.effectiveFrom, this.serviceId, this.staffId});
  final String id, scope, type;
  final int value;
  final DateTime effectiveFrom;
  final String? serviceId, staffId;

  factory CommissionRuleV.fromJson(Map<String, dynamic> j) => CommissionRuleV(
    id: j['id'].toString(),
    scope: j['scope'] as String? ?? 'service',
    type: j['type'] as String? ?? 'percent',
    value: parseInt(j['value']) ?? 0,
    effectiveFrom: DateTime.tryParse(j['effective_from'] as String? ?? '') ?? DateTime.now(),
    serviceId: j['service_id']?.toString(),
    staffId: j['staff_id']?.toString(),
  );
}

// ---- pengaturan owner ----

class VoucherV {
  const VoucherV({required this.id, required this.code, required this.type, required this.value, required this.startsAt, required this.endsAt, this.minAmount = 0, this.quotaTotal, this.quotaPerPatient, this.isActive = true, this.useCount = 0, this.useTotal = 0});
  final String id, code, type;
  final int value, minAmount, useCount, useTotal;
  final DateTime startsAt, endsAt;
  final int? quotaTotal, quotaPerPatient;
  final bool isActive;

  factory VoucherV.fromJson(Map<String, dynamic> j) => VoucherV(
    id: j['id'].toString(),
    code: j['code'] as String? ?? '',
    type: j['type'] as String? ?? 'percent',
    value: parseInt(j['value']) ?? 0,
    minAmount: parseInt(j['min_amount']) ?? 0,
    startsAt: parseDate(j['starts_at']) ?? DateTime.now(),
    endsAt: parseDate(j['ends_at']) ?? DateTime.now(),
    quotaTotal: parseInt(j['quota_total']),
    quotaPerPatient: parseInt(j['quota_per_patient']),
    isActive: j['is_active'] as bool? ?? true,
    useCount: parseInt(_m(j['usage'])['count']) ?? 0,
    useTotal: parseInt(_m(j['usage'])['total_discount']) ?? 0,
  );
}

class AnnouncementV {
  const AnnouncementV({required this.id, required this.title, required this.body, required this.roles, this.sendAt});
  final String id, title, body;
  final List<String> roles;
  final DateTime? sendAt;

  factory AnnouncementV.fromJson(Map<String, dynamic> j) => AnnouncementV(
    id: j['id'].toString(),
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    roles: parseStrings(j['roles']),
    sendAt: parseDate(j['send_at']),
  );
}

class PointsRulesV {
  const PointsRulesV({this.earnPerRupiah = 0, this.pointValue = 0, this.maxRedeemPercent = 0, this.expiryDays = 0, this.referrer = 0, this.referee = 0});
  final int earnPerRupiah, pointValue, maxRedeemPercent, expiryDays, referrer, referee;

  factory PointsRulesV.fromJson(Map<String, dynamic> j) => PointsRulesV(
    earnPerRupiah: parseInt(j['earn_per_rupiah']) ?? 0,
    pointValue: parseInt(j['point_value']) ?? 0,
    maxRedeemPercent: parseInt(j['max_redeem_percent']) ?? 0,
    expiryDays: parseInt(j['expiry_days']) ?? 0,
    referrer: parseInt(j['referral_reward_referrer']) ?? 0,
    referee: parseInt(j['referral_reward_referee']) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'earn_per_rupiah': earnPerRupiah,
    'point_value': pointValue,
    'max_redeem_percent': maxRedeemPercent,
    'expiry_days': expiryDays,
    'referral_reward_referrer': referrer,
    'referral_reward_referee': referee,
  };
}

class TemplateV {
  const TemplateV({required this.id, required this.kind, required this.key, required this.title, required this.content, this.isActive = true});
  final String id, kind, key, title;
  final Map<String, dynamic> content;
  final bool isActive;

  String get body => content['body'] as String? ?? '';

  factory TemplateV.fromJson(Map<String, dynamic> j) => TemplateV(
    id: j['id'].toString(),
    kind: j['kind'] as String? ?? '',
    key: j['key'] as String? ?? '',
    title: j['title'] as String? ?? '',
    content: _m(j['content']),
    isActive: j['is_active'] as bool? ?? true,
  );
}

class ExerciseV {
  const ExerciseV({required this.id, required this.name, this.areas = const [], this.level, this.videoUrl, this.steps = const [], this.sets, this.reps, this.durationSec, this.warnings, this.status = 'approved'});
  final String id, name, status;
  final List<String> areas, steps;
  final String? level, videoUrl, warnings;
  final int? sets, reps, durationSec;

  factory ExerciseV.fromJson(Map<String, dynamic> j) => ExerciseV(
    id: j['id'].toString(),
    name: j['name'] as String? ?? '',
    areas: parseStrings(j['body_area_codes']),
    level: j['level'] as String?,
    videoUrl: j['video_url'] as String?,
    steps: parseStrings(j['steps']),
    sets: parseInt(j['default_sets']),
    reps: parseInt(j['default_reps']),
    durationSec: parseInt(j['default_duration_sec']),
    warnings: j['warnings'] as String?,
    status: j['status'] as String? ?? 'approved',
  );
}

class ProgramItemV {
  const ProgramItemV({required this.id, required this.exercise, this.sets, this.reps, this.durationSec, this.perDay = 1, this.doneToday = false});
  final String id;
  final ExerciseV exercise;
  final int? sets, reps, durationSec;
  final int perDay;
  final bool doneToday;

  String get dose => [
    if (sets != null && reps != null) '$sets × $reps' else if (durationSec != null) '$durationSec detik',
    if (perDay > 1) '$perDay×/hari',
  ].join(' · ');

  factory ProgramItemV.fromJson(Map<String, dynamic> j) => ProgramItemV(
    id: j['id'].toString(),
    exercise: ExerciseV.fromJson(_m(j['exercise'])),
    sets: parseInt(j['sets']),
    reps: parseInt(j['reps']),
    durationSec: parseInt(j['duration_sec']),
    perDay: parseInt(j['per_day']) ?? 1,
    doneToday: j['done_today'] as bool? ?? false,
  );
}

class ProgramV {
  const ProgramV({required this.id, required this.items, this.startsOn, this.endsOn, this.note, this.status = 'active', this.therapistName = '', this.adherence = 0});
  final String id, status, therapistName;
  final List<ProgramItemV> items;
  final DateTime? startsOn, endsOn;
  final String? note;
  final int adherence;

  factory ProgramV.fromJson(Map<String, dynamic> j) => ProgramV(
    id: j['id'].toString(),
    items: [for (final i in _l(j['items'])) ProgramItemV.fromJson(i)],
    startsOn: j['starts_on'] == null ? null : DateTime.tryParse(j['starts_on'] as String),
    endsOn: j['ends_on'] == null ? null : DateTime.tryParse(j['ends_on'] as String),
    note: j['note'] as String?,
    status: j['status'] as String? ?? 'active',
    therapistName: j['therapist_name'] as String? ?? '',
    adherence: parseInt(j['adherence_week_pct']) ?? 0,
  );
}

// ---- laporan, audit, rekonsiliasi ----

class ReportSummaryV {
  const ReportSummaryV({required this.revenue, this.deltaPct = 0, this.series = const [], this.returningPct = 0, this.utilizationPct = 0, this.byTherapist = const [], this.alerts = const []});
  final int revenue;
  final double deltaPct, returningPct, utilizationPct;
  final List<({String label, int value})> series;
  final List<({String name, int sessions})> byTherapist;
  final List<({String kind, int count, int? amount})> alerts;

  factory ReportSummaryV.fromJson(Map<String, dynamic> j) {
    final r = _m(j['revenue']);
    return ReportSummaryV(
      revenue: parseInt(r['total']) ?? 0,
      deltaPct: parseDouble(r['delta_pct']) ?? 0,
      series: [for (final s in _l(r['series'])) (label: s['label'] as String? ?? '', value: parseInt(s['value']) ?? 0)],
      returningPct: parseDouble(j['returning_patients_pct']) ?? 0,
      utilizationPct: parseDouble(j['slot_utilization_pct']) ?? 0,
      byTherapist: [for (final t in _l(j['sessions_by_therapist'])) (name: t['name'] as String? ?? '', sessions: parseInt(t['sessions']) ?? 0)],
      alerts: [for (final a in _l(j['alerts'])) (kind: a['kind'] as String? ?? '', count: parseInt(a['count']) ?? 0, amount: parseInt(a['amount']))],
    );
  }
}

class ReportTableV {
  const ReportTableV({required this.columns, required this.rows, this.totals = const {}});
  final List<({String key, String label, String type})> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> totals;

  factory ReportTableV.fromJson(Map<String, dynamic> j) => ReportTableV(
    columns: [for (final c in _l(j['columns'])) (key: c['key'] as String? ?? '', label: c['label'] as String? ?? '', type: c['type'] as String? ?? 'text')],
    rows: _l(j['rows']),
    totals: _m(j['totals']),
  );
}

class AuditLogV {
  const AuditLogV({required this.id, required this.at, required this.action, this.actorName = '', this.objectType = '', this.objectId, this.deviceId, this.meta = const {}});
  final int id;
  final DateTime at;
  final String action, actorName, objectType;
  final String? objectId, deviceId;
  final Map<String, dynamic> meta;

  factory AuditLogV.fromJson(Map<String, dynamic> j) => AuditLogV(
    id: parseInt(j['id']) ?? 0,
    at: parseDate(j['at']) ?? DateTime.now(),
    action: j['action'] as String? ?? '',
    actorName: _m(j['actor'])['name'] as String? ?? '',
    objectType: j['object_type'] as String? ?? '',
    objectId: j['object_id'] as String?,
    deviceId: j['device_id'] as String?,
    meta: _m(j['meta']),
  );
}

class SettlementV {
  const SettlementV({required this.id, required this.gross, required this.status, this.date, this.ref = '', this.mdr = 0, this.net = 0, this.note});
  final String id, status, ref;
  final int gross, mdr, net;
  final DateTime? date;
  final String? note;

  factory SettlementV.fromJson(Map<String, dynamic> j) => SettlementV(
    id: j['id'].toString(),
    gross: parseInt(j['gross']) ?? 0,
    status: j['match_status'] as String? ?? '',
    date: j['date'] == null ? null : DateTime.tryParse(j['date'] as String),
    ref: j['gateway_ref'] as String? ?? '',
    mdr: parseInt(j['mdr']) ?? 0,
    net: parseInt(j['net']) ?? 0,
    note: j['checked_note'] as String?,
  );
}

class NotificationV {
  const NotificationV({required this.id, required this.type, required this.title, required this.body, required this.createdAt, this.deepLink, this.readAt});
  final String id, type, title, body;
  final String? deepLink;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  factory NotificationV.fromJson(Map<String, dynamic> j) => NotificationV(
    id: j['id'].toString(),
    type: j['type'] as String? ?? '',
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    deepLink: j['deep_link'] as String?,
    createdAt: parseDate(j['created_at']) ?? DateTime.now(),
    readAt: parseDate(j['read_at']),
  );
}

// ---- persetujuan keuangan & latihan ----

class ApprovalV {
  const ApprovalV({required this.id, required this.type, required this.status, this.requestedBy = '', this.createdAt, this.payload = const {}, this.subjectId});
  final String id, type, status, requestedBy;
  final DateTime? createdAt;
  final Map<String, dynamic> payload;
  final String? subjectId;

  factory ApprovalV.fromJson(Map<String, dynamic> j) => ApprovalV(
    id: j['id'].toString(),
    type: j['type'] as String? ?? '',
    status: j['status'] as String? ?? '',
    requestedBy: _m(j['requested_by'])['name'] as String? ?? '',
    createdAt: parseDate(j['created_at']),
    payload: _m(j['payload']),
    subjectId: j['subject_id']?.toString(),
  );
}

// ---- katalog layanan (OW-09) ----

class ServiceV {
  const ServiceV({
    required this.id,
    required this.name,
    required this.durationMin,
    required this.price,
    this.memberPrice,
    this.perExtraPoint = 0,
    this.injurySurcharge = 0,
    this.category,
    this.homeVisit = false,
    this.isActive = true,
    this.version,
    this.branchIds = const [],
  });
  final String id, name;
  final int durationMin, price, perExtraPoint, injurySurcharge;
  final int? memberPrice, version;
  final String? category;
  final bool homeVisit, isActive;
  final List<String> branchIds;

  factory ServiceV.fromJson(Map<String, dynamic> j) => ServiceV(
    id: j['id'].toString(),
    name: j['name'] as String? ?? '',
    durationMin: parseInt(j['duration_min']) ?? 0,
    price: parseInt(j['price']) ?? 0,
    memberPrice: parseInt(j['member_price']),
    perExtraPoint: parseInt(j['price_per_extra_point']) ?? 0,
    injurySurcharge: parseInt(j['injury_surcharge']) ?? 0,
    category: j['category'] as String?,
    homeVisit: j['home_visit_allowed'] as bool? ?? false,
    isActive: j['is_active'] as bool? ?? true,
    version: parseInt(j['version']),
    branchIds: parseStrings(j['branch_ids']),
  );
}

// ---- booking masuk (KS-07) ----

/// Booking dari aplikasi pasien / website / staf, menunggu keputusan front desk.
/// Sesi baru dibuat backend saat booking diterima.
class BookingReqV {
  const BookingReqV({
    required this.id,
    required this.status,
    required this.requestedStart,
    this.source = 'patient_app',
    this.proposedStart,
    this.patientId,
    this.patientName,
    this.patientNumber,
    this.guestName,
    this.guestPhone,
    this.serviceId,
    this.serviceName = '',
    this.branchId,
    this.homeVisit = false,
    this.note,
    this.slotStillFree = true,
    this.dpStatus,
    this.createdAt,
  });
  final String id, status, source, serviceName;
  final DateTime requestedStart;
  final DateTime? proposedStart, createdAt;
  final String? patientId, patientName, guestName, guestPhone, serviceId, branchId, note, dpStatus;
  final int? patientNumber;
  final bool homeVisit, slotStillFree;

  DateTime get start => proposedStart ?? requestedStart;
  String get displayName => patientName ?? guestName ?? 'Tamu';
  bool get isNewPatient => patientId == null;

  factory BookingReqV.fromJson(Map<String, dynamic> j) {
    final p = _m(j['patient']);
    final g = _m(j['guest']);
    final s = _m(j['service']);
    return BookingReqV(
      id: j['id'].toString(),
      status: j['status'] as String? ?? 'pending',
      source: j['source'] as String? ?? 'patient_app',
      requestedStart: parseDate(j['requested_start']) ?? DateTime.now(),
      proposedStart: parseDate(j['proposed_start']),
      patientId: p['id']?.toString(),
      patientName: p['name'] as String?,
      patientNumber: parseInt(p['number']),
      guestName: g['name'] as String?,
      guestPhone: g['phone'] as String?,
      serviceId: s['id']?.toString(),
      serviceName: s['name'] as String? ?? '',
      branchId: j['branch_id']?.toString(),
      homeVisit: j['location_type'] == 'home_visit',
      note: j['note'] as String?,
      slotStillFree: j['slot_still_free'] as bool? ?? true,
      dpStatus: j['dp_status'] as String?,
      createdAt: parseDate(j['created_at']),
    );
  }
}

const bookingSourceLabels = {'patient_app': 'Aplikasi pasien', 'website': 'Website', 'staff': 'Front desk'};

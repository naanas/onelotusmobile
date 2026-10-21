import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/billing.dart';
import '../models/json.dart';
import '../providers.dart';
import 'api_client.dart';

/// Endpoint fase 2–3 untuk staf: tagihan, pembayaran, struk, refund, piutang, kas, komisi, laporan,
/// pengaturan owner, latihan, notifikasi. Kontrak: `backend/docs/openapi.yaml`.
class BillingApi {
  BillingApi(this.api);

  final ApiClient api;

  static String key() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static Map<String, String> _idem() => {'Idempotency-Key': key()};

  // ── tagihan ─────────────────────────────────────────────────────────────

  Future<CursorPage<InvoiceV>> invoices({String? status, DateTime? date, String? method, String? q, String? cursor}) =>
      api.getPage('/v1/invoices', InvoiceV.fromJson, query: {
        'status': status,
        'date': formatDay(date),
        'method': method,
        'q': q,
        'cursor': cursor,
      });

  Future<InvoiceV> invoice(String id) => api.get('/v1/invoices/$id', (d) => InvoiceV.fromJson(asMap(d)));

  /// Tagihan sesi (null bila belum ada).
  Future<InvoiceV?> invoiceForSession(String sessionId) =>
      api.get('/v1/sessions/$sessionId/invoice', (d) => d == null ? null : InvoiceV.fromJson(asMap(d)));

  Future<InvoiceV> sellPackage(String patientId, String packageId) => api.post(
    '/v1/invoices',
    {'kind': 'package', 'patient_id': patientId, 'package_id': packageId},
    (d) => InvoiceV.fromJson(asMap(d)),
    headers: _idem(),
  );

  Future<InvoiceV> updateInvoice(String id, Map<String, dynamic> body) =>
      api.patch('/v1/invoices/$id', body, (d) => InvoiceV.fromJson(asMap(d)));

  Future<InvoiceV> issue(String id) => api.post('/v1/invoices/$id/issue', null, (d) => InvoiceV.fromJson(asMap(d)));

  Future<InvoiceV> cancelInvoice(String id, String reason) =>
      api.post('/v1/invoices/$id/cancel', {'reason': reason}, (d) => InvoiceV.fromJson(asMap(d)));

  Future<PaymentResult> pay(String invoiceId, Map<String, dynamic> body) => api.post(
    '/v1/invoices/$invoiceId/payments',
    body,
    (d) => PaymentResult.fromJson(asMap(d)),
    headers: _idem(),
  );

  Future<PaymentResult> payment(String id) => api.get('/v1/payments/$id', (d) => PaymentResult.fromJson(asMap(d)));

  Future<PaymentV> cancelPayment(String id) => api.post('/v1/payments/$id/cancel', null, (d) => PaymentV.fromJson(asMap(d)));

  Future<PaymentV> paymentLink(String invoiceId) =>
      api.post('/v1/invoices/$invoiceId/payment-link', null, (d) => PaymentV.fromJson(asMap(d)));

  Future<List<PaymentV>> transfersToVerify() =>
      api.get('/v1/payments', (d) => parseList(d, PaymentV.fromJson), query: {'status': 'awaiting_verification'});

  /// Signed URL foto bukti transfer (5 menit).
  Future<String> transferProof(String paymentId) => api.get('/v1/payments/$paymentId/proof', (d) => asMap(d)['url'] as String);

  Future<PaymentResult> verify(String paymentId, {required bool approve, String? reason}) => api.post(
    '/v1/payments/$paymentId/verify',
    {'decision': approve ? 'approve' : 'reject', 'reason': reason},
    (d) => PaymentResult.fromJson(asMap(d)),
  );

  Future<({bool valid, int discount, String? reason})> validateVoucher(String code, String invoiceId) => api.get(
    '/v1/vouchers/validate',
    (d) {
      final m = asMap(d);
      return (valid: m['valid'] as bool? ?? false, discount: parseInt(m['discount']) ?? 0, reason: m['reason'] as String?);
    },
    query: {'code': code, 'invoice_id': invoiceId},
  );

  /// Unggah file (§12): tiket → PUT ke Storage → complete. Hasil: id lampiran.
  Future<String> upload({required String ownerType, required String ownerId, required String kind, required String mime, required List<int> bytes}) async {
    final t = await api.post('/v1/uploads', {
      'owner_type': ownerType,
      'owner_id': ownerId,
      'kind': kind,
      'mime': mime,
      'size_bytes': bytes.length,
    }, asMap, headers: _idem());
    final id = t['attachment_id'].toString();
    await Dio().put<void>(
      t['upload_url'] as String,
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {'Content-Type': mime, Headers.contentLengthHeader: bytes.length}),
    );
    await api.post('/v1/uploads/$id/complete', null, (_) {});
    return id;
  }

  // ── struk, refund, piutang ──────────────────────────────────────────────

  Future<ReceiptV> receipt(String id) => api.get('/v1/receipts/$id', (d) => ReceiptV.fromJson(asMap(d)));

  Future<void> sendReceipt(String id) => api.post('/v1/receipts/$id/send', null, (_) {});

  Future<String> receiptPdf(String id) => api.get('/v1/receipts/$id/pdf', (d) => asMap(d)['url'] as String);

  Future<RefundV> refund(String invoiceId, Map<String, dynamic> body) =>
      api.post('/v1/invoices/$invoiceId/refunds', body, (d) => RefundV.fromJson(asMap(d)));

  Future<CursorPage<ReceivableV>> receivables({int minAgeDays = 0, String? cursor}) =>
      api.getPage('/v1/receivables', ReceivableV.fromJson, query: {'min_age_days': minAgeDays, 'cursor': cursor});

  Future<void> remind(List<String> invoiceIds) => api.post('/v1/receivables/remind', {'invoice_ids': invoiceIds}, (_) {});

  Future<List<OwnershipV>> patientPackages(String patientId) =>
      api.get('/v1/patients/$patientId/packages', (d) => parseList(d, OwnershipV.fromJson));

  Future<PointsSummaryV> patientPoints(String patientId) =>
      api.get('/v1/patients/$patientId/points', (d) => PointsSummaryV.fromJson(asMap(d)));

  // ── kas ─────────────────────────────────────────────────────────────────

  Future<List<CashCarriedV>> myCash() => api.get('/v1/me/cash', (d) => parseList(d, CashCarriedV.fromJson));

  Future<HandoverV> handover(DateTime date, String cashierId) => api.post(
    '/v1/cash-handovers',
    {'business_date': formatDay(date), 'cashier_id': cashierId},
    (d) => HandoverV.fromJson(asMap(d)),
  );

  Future<List<HandoverV>> handovers({String? status}) =>
      api.get('/v1/cash-handovers', (d) => parseList(d, HandoverV.fromJson), query: {'status': status});

  Future<HandoverV> receiveCash(String id, int amount, String? note) => api.post(
    '/v1/cash-handovers/$id/receive',
    {'amount_received': amount, 'note': note},
    (d) => HandoverV.fromJson(asMap(d)),
  );

  Future<ClosingPreviewV> closingPreview({DateTime? date}) =>
      api.get('/v1/cash-closings/preview', (d) => ClosingPreviewV.fromJson(asMap(d)), query: {'date': formatDay(date)});

  Future<void> closeCash(DateTime date, int counted, String? note) => api.post(
    '/v1/cash-closings',
    {'business_date': formatDay(date), 'counted_cash': counted, 'note': note},
    (_) {},
  );

  // ── komisi ──────────────────────────────────────────────────────────────

  Future<CommissionSummaryV> myCommissions({String? period}) =>
      api.get('/v1/me/commissions', (d) => CommissionSummaryV.fromJson(asMap(d)), query: {'period': period});

  Future<List<CommissionSummaryV>> commissions({String? period}) =>
      api.get('/v1/commissions', (d) => parseList(d, CommissionSummaryV.fromJson), query: {'period': period});

  Future<List<CommissionSummaryV>> commissionAction(String period, {required bool paid, List<String>? staffIds}) => api.post(
    paid ? '/v1/commissions/mark-paid' : '/v1/commissions/approve',
    {'period': period, 'staff_ids': ?staffIds},
    (d) => parseList(d, CommissionSummaryV.fromJson),
  );

  Future<List<CommissionRuleV>> commissionRules() =>
      api.get('/v1/commission-rules', (d) => parseList(d, CommissionRuleV.fromJson));

  Future<CommissionRuleV> saveCommissionRule(String? id, Map<String, dynamic> body) => id == null
      ? api.post('/v1/commission-rules', body, (d) => CommissionRuleV.fromJson(asMap(d)))
      : api.patch('/v1/commission-rules/$id', body, (d) => CommissionRuleV.fromJson(asMap(d)));

  // ── pengaturan owner ────────────────────────────────────────────────────

  Future<List<ServiceV>> catalogServices() => api.get('/v1/services', (d) => parseList(d, ServiceV.fromJson));

  Future<ServiceV> saveService(String? id, Map<String, dynamic> body) => id == null
      ? api.post('/v1/services', {'id': '00000000-0000-0000-0000-000000000000', ...body}, (d) => ServiceV.fromJson(asMap(d)))
      : api.patch('/v1/services/$id', {'id': id, ...body}, (d) => ServiceV.fromJson(asMap(d)));

  Future<List<PackageV>> packages() => api.get('/v1/packages', (d) => parseList(d, PackageV.fromJson));

  Future<PackageV> savePackage(String? id, Map<String, dynamic> body) => id == null
      ? api.post('/v1/packages', {'id': '00000000-0000-0000-0000-000000000000', ...body}, (d) => PackageV.fromJson(asMap(d)))
      : api.patch('/v1/packages/$id', {'id': id, ...body}, (d) => PackageV.fromJson(asMap(d)));

  Future<List<VoucherV>> vouchers() => api.get('/v1/vouchers', (d) => parseList(d, VoucherV.fromJson));

  Future<VoucherV> saveVoucher(String? id, Map<String, dynamic> body) => id == null
      ? api.post('/v1/vouchers', body, (d) => VoucherV.fromJson(asMap(d)))
      : api.patch('/v1/vouchers/$id', body, (d) => VoucherV.fromJson(asMap(d)));

  Future<List<AnnouncementV>> announcements() => api.get('/v1/announcements', (d) => parseList(d, AnnouncementV.fromJson));

  Future<AnnouncementV> createAnnouncement(Map<String, dynamic> body) =>
      api.post('/v1/announcements', body, (d) => AnnouncementV.fromJson(asMap(d)));

  Future<PointsRulesV> pointsRules() => api.get('/v1/settings/points', (d) => PointsRulesV.fromJson(asMap(d)));

  Future<PointsRulesV> savePointsRules(PointsRulesV r) =>
      api.put('/v1/settings/points', r.toJson(), (d) => PointsRulesV.fromJson(asMap(d)));

  Future<List<TemplateV>> templates() => api.get('/v1/templates', (d) => parseList(d, TemplateV.fromJson));

  Future<TemplateV> saveTemplate(String? id, Map<String, dynamic> body) => id == null
      ? api.post('/v1/templates', body, (d) => TemplateV.fromJson(asMap(d)))
      : api.patch('/v1/templates/$id', body, (d) => TemplateV.fromJson(asMap(d)));

  // ── latihan ─────────────────────────────────────────────────────────────

  Future<List<ExerciseV>> exercises() => api.get('/v1/exercises', (d) => parseList(d, ExerciseV.fromJson));

  Future<ExerciseV> saveExercise(String? id, Map<String, dynamic> body) => id == null
      ? api.post('/v1/exercises', {'id': '00000000-0000-0000-0000-000000000000', ...body}, (d) => ExerciseV.fromJson(asMap(d)))
      : api.patch('/v1/exercises/$id', {'id': id, ...body}, (d) => ExerciseV.fromJson(asMap(d)));

  Future<List<ProgramV>> programs(String patientId) =>
      api.get('/v1/patients/$patientId/exercise-programs', (d) => parseList(d, ProgramV.fromJson));

  Future<ProgramV> sendProgram(String patientId, Map<String, dynamic> body) =>
      api.post('/v1/patients/$patientId/exercise-programs', body, (d) => ProgramV.fromJson(asMap(d)));

  // ── laporan, ekspor, audit, rekonsiliasi, kampanye ──────────────────────

  Future<ReportSummaryV> summary({DateTime? from, DateTime? to}) => api.get(
    '/v1/reports/summary',
    (d) => ReportSummaryV.fromJson(asMap(d)),
    query: {'from': formatDay(from), 'to': formatDay(to)},
  );

  Future<ReportTableV> report(String name, {DateTime? from, DateTime? to, String? groupBy}) => api.get(
    '/v1/reports/$name',
    (d) => ReportTableV.fromJson(asMap(d)),
    query: {'from': formatDay(from), 'to': formatDay(to), 'group_by': groupBy},
  );

  Future<({String id, String status, String? url})> export(Map<String, dynamic> body) =>
      api.post('/v1/exports', body, (d) => _export(asMap(d)));

  Future<({String id, String status, String? url})> exportStatus(String id) => api.get('/v1/exports/$id', (d) => _export(asMap(d)));

  static ({String id, String status, String? url}) _export(Map<String, dynamic> m) =>
      (id: m['id'].toString(), status: m['status'] as String? ?? '', url: m['download_url'] as String?);

  Future<CursorPage<AuditLogV>> auditLogs({String? action, String? cursor}) =>
      api.getPage('/v1/audit-logs', AuditLogV.fromJson, query: {'action': action, 'cursor': cursor});

  Future<List<SettlementV>> settlements({DateTime? date, String? status}) => api.get(
    '/v1/reconciliation',
    (d) => parseList(d, SettlementV.fromJson),
    query: {'date': formatDay(date), 'status': status},
  );

  Future<SettlementV> checkSettlement(String id, String note) =>
      api.post('/v1/reconciliation/$id/check', {'note': note}, (d) => SettlementV.fromJson(asMap(d)));

  Future<({int count, int optedOut, int recent, String sample})> campaignPreview(Map<String, dynamic> body) => api.post(
    '/v1/campaigns/preview',
    body,
    (d) {
      final m = asMap(d);
      final sk = m['skipped'] is Map ? asMap(m['skipped']) : const <String, dynamic>{};
      return (
        count: parseInt(m['recipient_count']) ?? 0,
        optedOut: parseInt(sk['opted_out']) ?? 0,
        recent: parseInt(sk['reminded_last_7d']) ?? 0,
        sample: m['sample_message'] as String? ?? '',
      );
    },
  );

  Future<int> sendCampaign(Map<String, dynamic> body) =>
      api.post('/v1/campaigns', body, (d) => parseInt(asMap(d)['queued']) ?? 0);

  // ── notifikasi ──────────────────────────────────────────────────────────

  Future<CursorPage<NotificationV>> notifications({bool unreadOnly = false, String? cursor}) => api.getPage(
    '/v1/notifications',
    NotificationV.fromJson,
    query: {if (unreadOnly) 'unread_only': 'true', 'cursor': cursor},
  );

  Future<void> markRead(String id) => api.post('/v1/notifications/$id/read', null, (_) {});

  Future<void> markAllRead() => api.post('/v1/notifications/read-all', null, (_) {});

  // ── booking masuk (KS-07) ───────────────────────────────────────────────

  Future<List<BookingReqV>> bookings({String? status = 'pending', String? branchId}) => api.get(
    '/v1/bookings',
    (d) => parseList(d, BookingReqV.fromJson),
    query: {'status': status, 'branch_id': branchId},
  );

  /// Terima → backend membuat sesi (terapis pilihan pasien, atau siapa saja yang kosong).
  Future<BookingReqV> acceptBooking(String id, {String? therapistId}) => api.post(
    '/v1/bookings/$id/accept',
    {'therapist_id': ?therapistId},
    (d) => BookingReqV.fromJson(asMap(d)),
  );

  /// Usulkan jam lain → pasien memilih terima / jam lain di aplikasinya.
  Future<BookingReqV> proposeBooking(String id, DateTime start, {String? reason}) => api.post(
    '/v1/bookings/$id/propose',
    {'proposed_start': start.toUtc().toIso8601String(), 'reason': reason},
    (d) => BookingReqV.fromJson(asMap(d)),
  );

  Future<BookingReqV> rejectBooking(String id, String reason) =>
      api.post('/v1/bookings/$id/reject', {'reason': reason}, (d) => BookingReqV.fromJson(asMap(d)));

  // ── persetujuan (refund, diskon manual, usulan latihan, selisih kas) ────

  Future<List<ApprovalV>> approvals(String type) =>
      api.get('/v1/approvals', (d) => parseList(d, ApprovalV.fromJson), query: {'type': type, 'status': 'pending'});

  Future<void> decide(String id, {required bool approve, String? reason}) =>
      api.post('/v1/approvals/$id/decide', {'decision': approve ? 'approve' : 'reject', 'reason': reason}, (_) {});
}

final billingApiProvider = Provider<BillingApi>((ref) => BillingApi(ref.watch(apiClientProvider)));

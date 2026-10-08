/// Siklus status sesi (§6.2). `api` = nilai di API/JSON.
enum SessionStatus {
  awaitingConfirmation('awaiting_confirmation', 'Menunggu konfirmasi'),
  scheduled('scheduled', 'Dijadwalkan'),
  arrived('arrived', 'Hadir'),
  running('running', 'Berjalan'),
  done('done', 'Selesai'),
  unpaid('unpaid', 'Belum bayar'),
  paid('paid', 'Lunas'),
  noShow('no_show', 'Tidak datang'),
  cancelled('cancelled', 'Dibatalkan');

  const SessionStatus(this.api, this.label);
  final String api;
  final String label;

  static SessionStatus fromApi(String? v) => values.firstWhere(
    (s) => s.api == v,
    orElse: () => SessionStatus.scheduled,
  );
}

/// Siklus status pembayaran (§6.4.1).
enum PaymentStatus {
  draft('draft', 'Draft'),
  unpaid('unpaid', 'Belum bayar'),
  pending('pending', 'Menunggu pembayaran'),
  pendingVerify('pending_verify', 'Menunggu verifikasi'),
  partial('partial', 'Belum lunas'),
  paid('paid', 'Lunas'),
  failed('failed', 'Gagal'),
  expired('expired', 'Kedaluwarsa'),
  cancelled('cancelled', 'Dibatalkan'),
  refundPartial('refund_partial', 'Refund sebagian'),
  refundFull('refund_full', 'Refund penuh');

  const PaymentStatus(this.api, this.label);
  final String api;
  final String label;

  static PaymentStatus fromApi(String? v) =>
      values.firstWhere((s) => s.api == v, orElse: () => PaymentStatus.draft);
}

/// Jenis tampilan untuk tiap kode error (§12.1).
enum FeedbackKind {
  /// Ditangani layar: teks di bawah field (validation, package_empty, points_insufficient).
  inline,

  /// Ditangani layar: area konten diganti pesan error (not_found).
  content,
  toast,
  banner,
  sheet,
  dialog,

  /// Layar error penuh (auth_expired → login).
  fullScreen,
}

enum BannerTone { info, warn, crit }

/// Katalog pesan standar (§12.4). Template `{n}`, `{jam}`, `{saldo}` diisi dari [AppError.args].
enum ErrorCode {
  networkOffline(
    'network_offline',
    FeedbackKind.banner,
    'Kamu sedang offline. Data tersimpan di HP.',
    banner: BannerTone.warn,
  ),
  networkTimeout(
    'network_timeout',
    FeedbackKind.toast,
    'Koneksi lambat. Coba lagi.',
  ),
  authExpired(
    'auth_expired',
    FeedbackKind.fullScreen,
    'Sesi login berakhir. Masuk lagi untuk melanjutkan.',
  ),
  forbidden(
    'forbidden',
    FeedbackKind.toast,
    'Kamu tidak punya akses ke data ini.',
  ),
  notFound(
    'not_found',
    FeedbackKind.content,
    'Data tidak ditemukan. Mungkin sudah diarsipkan.',
  ),
  validation(
    'validation',
    FeedbackKind.inline,
    'Periksa lagi isian yang ditandai.',
  ),
  duplicatePatient(
    'duplicate_patient',
    FeedbackKind.sheet,
    'Pasien dengan nama & tanggal lahir ini sudah ada.',
  ),
  editConflict(
    'edit_conflict',
    FeedbackKind.sheet,
    'Catatan ini juga diubah di perangkat lain.',
  ),
  rateLimited(
    'rate_limited',
    FeedbackKind.toast,
    'Terlalu banyak permintaan. Tunggu sebentar.',
    info: true,
  ),
  serverError(
    'server_error',
    FeedbackKind.toast,
    'Ada gangguan di server. Coba beberapa saat lagi.',
  ),
  uploadFailed(
    'upload_failed',
    FeedbackKind.inline,
    'Gagal mengunggah. Ketuk untuk coba lagi.',
  ),
  syncFailed('sync_failed', FeedbackKind.sheet, '{n} catatan belum terkirim.'),
  permLocation(
    'perm_location',
    FeedbackKind.dialog,
    'Lokasi dipakai untuk check-in home visit.',
  ),
  permCamera(
    'perm_camera',
    FeedbackKind.dialog,
    'Kamera dipakai untuk foto rontgen & dokumen.',
  ),
  checkinOutOfRange(
    'checkin_out_of_range',
    FeedbackKind.dialog,
    'Kamu ±{jarak} dari alamat. Tetap check-in?',
  ),
  qrisExpired('qris_expired', FeedbackKind.inline, 'Kode QR kedaluwarsa.'),
  paymentFailed(
    'payment_failed',
    FeedbackKind.dialog,
    'Pembayaran belum berhasil. Tagihan belum lunas.',
  ),
  paymentPendingUnknown(
    'payment_pending_unknown',
    FeedbackKind.banner,
    'Menunggu konfirmasi pembayaran. Jangan tagih ulang dulu.',
    banner: BannerTone.warn,
  ),
  packageEmpty(
    'package_empty',
    FeedbackKind.inline,
    'Kuota paket habis. Pilih metode lain atau beli paket baru.',
  ),
  transferPendingVerify(
    'transfer_pending_verify',
    FeedbackKind.banner,
    'Bukti transfer menunggu verifikasi.',
    banner: BannerTone.info,
  ),
  paymentDoubleGuard(
    'payment_double_guard',
    FeedbackKind.dialog,
    'Tagihan ini sudah dibayar pukul {jam}. Jangan tagih ulang.',
  ),
  discountNeedsApproval(
    'discount_needs_approval',
    FeedbackKind.banner,
    'Diskon menunggu persetujuan owner.',
    banner: BannerTone.warn,
  ),
  pointsInsufficient(
    'points_insufficient',
    FeedbackKind.inline,
    'Poin belum cukup. Saldo: {saldo} poin.',
  ),
  refundNotSupported(
    'refund_not_supported',
    FeedbackKind.sheet,
    'Refund QRIS tidak bisa otomatis. Catat pengembalian manual.',
  ),
  waSendFailed(
    'wa_send_failed',
    FeedbackKind.toast,
    'Struk belum terkirim ke WhatsApp. Coba lagi.',
  ),
  unknown(
    'unknown',
    FeedbackKind.toast,
    'Ada yang tidak beres. Coba lagi, atau laporkan dengan kode di bawah.',
  );

  const ErrorCode(
    this.code,
    this.kind,
    this.template, {
    this.banner = BannerTone.warn,
    this.info = false,
  });

  final String code;
  final FeedbackKind kind;
  final String template;
  final BannerTone banner;

  /// Toast info (ikon brand), bukan toast error.
  final bool info;

  static ErrorCode fromCode(String? code) => ErrorCode.values.firstWhere(
    (e) => e.code == code,
    orElse: () => ErrorCode.unknown,
  );
}

/// Error ber-tipe yang dilempar lapisan data; `AppFeedback.error` memilih tampilannya (§12.7).
class AppError implements Exception {
  const AppError(
    this.type, {
    this.refId,
    this.fieldErrors = const {},
    this.args = const {},
  });

  /// Dari format error API seragam: `{code, message, errors, ref}` (§12.7).
  factory AppError.fromApi(Map<String, dynamic> body) => AppError(
    ErrorCode.fromCode(body['code'] as String?),
    refId: body['ref'] as String?,
    fieldErrors: {
      for (final e in ((body['errors'] as Map?) ?? const {}).entries)
        e.key.toString(): [
          for (final m in (e.value as List? ?? const [])) m.toString(),
        ],
    },
  );

  final ErrorCode type;

  /// Kode referensi dari server, mis. `OL-7F3A`.
  final String? refId;

  /// Pesan per field untuk `validation` (422).
  final Map<String, List<String>> fieldErrors;
  final Map<String, Object> args;

  String get code => type.code;
  FeedbackKind get kind => type.kind;

  String get message => type.template.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (m) => args[m[1]]?.toString() ?? m[0]!,
  );

  String? fieldError(String field) => fieldErrors[field]?.firstOrNull;

  @override
  String toString() => 'AppError($code${refId == null ? '' : ', ref: $refId'})';
}

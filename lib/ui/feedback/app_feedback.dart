import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../ol_banner.dart';
import '../ol_button.dart';
import '../ol_icon.dart';
import '../ol_text_field.dart';
import 'app_error.dart';

export 'app_error.dart';

class FeedbackAction {
  const FeedbackAction(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
}

enum ConfirmChoice { confirm, alternative, cancel }

class ConfirmResult {
  const ConfirmResult(this.choice, [this.reason]);
  final ConfirmChoice choice;

  /// Isi alasan bila [ConfirmSpec.reasonLabel] diisi.
  final String? reason;
  bool get confirmed => choice == ConfirmChoice.confirm;
}

/// Dialog konfirmasi (§12.5). Judul = pertanyaan, tombol = kata kerja (bukan Ya/Tidak).
class ConfirmSpec {
  const ConfirmSpec({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Kembali',
    this.danger = true,
    this.alternativeLabel,
    this.reasonLabel,
    this.extra,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  /// Tombol utama berwarna `crit`.
  final bool danger;

  /// Opsi kedua berisiko, mis. "Buang perubahan" / "Tetap keluar" (crit, teks).
  final String? alternativeLabel;

  /// Bila diisi, dialog meminta alasan wajib sebelum tombol utama aktif.
  final String? reasonLabel;

  /// Konten tambahan, mis. contoh pesan WA.
  final Widget? extra;
}

class SheetAction<T> {
  const SheetAction(
    this.label,
    this.value, {
    this.variant = OlButtonVariant.primary,
  });
  final String label;
  final T value;
  final OlButtonVariant variant;
}

class BannerSpec {
  const BannerSpec({
    required this.id,
    required this.message,
    this.tone = OlBannerTone.warn,
    this.icon,
    this.action,
  });

  final String id;
  final String message;
  final OlBannerTone tone;
  final OlIconData? icon;
  final FeedbackAction? action;
}

/// Satu pintu untuk semua feedback (§12). Layar tidak boleh memanggil showDialog/SnackBar sendiri.
class AppFeedback {
  AppFeedback({required this.messengerKey, required this.navigatorKey});

  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final GlobalKey<NavigatorState> navigatorKey;

  /// Dipasang router (Tahap 3) untuk `auth_expired` → layar penuh lalu login.
  VoidCallback? onAuthExpired;

  final ValueNotifier<List<BannerSpec>> banners = ValueNotifier(const []);
  bool _dialogOpen = false;

  BuildContext? get _ctx => navigatorKey.currentContext;

  // ── Toast ────────────────────────────────────────────────────────────────

  void success(String message, {FeedbackAction? action}) {
    HapticFeedback.lightImpact();
    _toast(_ToastKind.success, message, action: action);
  }

  void info(String message) => _toast(_ToastKind.info, message);

  /// Memilih tampilan dari katalog §12.4. Kembalikan `false` bila error harus
  /// ditampilkan oleh layar sendiri (inline / content).
  bool error(AppError error, {VoidCallback? retry}) {
    switch (error.kind) {
      case FeedbackKind.inline:
      case FeedbackKind.content:
        return false;
      case FeedbackKind.toast:
        if (error.type.info) {
          info(error.message);
        } else {
          HapticFeedback.heavyImpact();
          _toast(
            _ToastKind.error,
            error.message,
            refId: error.refId,
            action: retry == null ? null : FeedbackAction('Coba lagi', retry),
          );
        }
      case FeedbackKind.banner:
        banner(
          BannerSpec(
            id: error.code,
            message: error.message,
            tone: switch (error.type.banner) {
              BannerTone.info => OlBannerTone.info,
              BannerTone.warn => OlBannerTone.warn,
              BannerTone.crit => OlBannerTone.crit,
            },
            icon: switch (error.type) {
              ErrorCode.networkOffline => OlIcons.offline,
              ErrorCode.paymentPendingUnknown => OlIcons.clock,
              _ => null,
            },
          ),
        );
      case FeedbackKind.sheet:
        sheet<bool>(
          title: error.message,
          refId: error.refId,
          actions: [
            if (retry != null) const SheetAction('Coba lagi', true),
            const SheetAction(
              'Tutup',
              false,
              variant: OlButtonVariant.secondary,
            ),
          ],
        ).then((again) {
          if (again ?? false) retry?.call();
        });
      case FeedbackKind.dialog:
        confirm(
          ConfirmSpec(
            title: error.message,
            message: error.refId == null ? '' : 'Ref: ${error.refId}',
            confirmLabel: retry == null ? 'Mengerti' : 'Coba lagi',
            danger: false,
          ),
        ).then((ok) {
          if (ok) retry?.call();
        });
      case FeedbackKind.fullScreen:
        onAuthExpired?.call();
    }
    return true;
  }

  void _toast(
    _ToastKind kind,
    String message, {
    String? refId,
    FeedbackAction? action,
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    // Maks 1 toast: yang baru menggantikan yang lama.
    messenger.hideCurrentSnackBar();
    final duration = switch (kind) {
      _ToastKind.error when action != null => const Duration(days: 1),
      _ToastKind.error => const Duration(seconds: 6),
      _ => const Duration(seconds: 3),
    };
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        padding: EdgeInsets.zero,
        content: _ToastContent(
          kind: kind,
          message: message,
          refId: refId,
          action: action,
          messenger: messenger,
        ),
      ),
    );
  }

  // ── Banner ───────────────────────────────────────────────────────────────

  void banner(BannerSpec spec) {
    banners.value = [
      for (final b in banners.value)
        if (b.id != spec.id) b,
      spec,
    ];
  }

  void clearBanner(String id) {
    banners.value = [
      for (final b in banners.value)
        if (b.id != id) b,
    ];
  }

  // ── Dialog ───────────────────────────────────────────────────────────────

  Future<bool> confirm(ConfirmSpec spec) async =>
      (await choose(spec)).confirmed;

  /// Dialog dengan 3 kemungkinan hasil (confirm / alternative / cancel) + alasan opsional.
  Future<ConfirmResult> choose(ConfirmSpec spec) async {
    final ctx = _ctx;
    // Maks 1 dialog pada satu waktu (§12.1).
    if (ctx == null || _dialogOpen) {
      return const ConfirmResult(ConfirmChoice.cancel);
    }
    _dialogOpen = true;
    try {
      final result = await showDialog<ConfirmResult>(
        context: ctx,
        barrierDismissible: true, // ketuk di luar = batal
        barrierColor: ctx.ol.scrim,
        builder: (_) => _ConfirmDialog(spec: spec),
      );
      return result ?? const ConfirmResult(ConfirmChoice.cancel);
    } finally {
      _dialogOpen = false;
    }
  }

  // ── Bottom sheet ─────────────────────────────────────────────────────────

  Future<T?> sheet<T>({
    required String title,
    String? message,
    String? refId,
    Widget? child,
    List<SheetAction<T>> actions = const [],
  }) async {
    final ctx = _ctx;
    if (ctx == null) return null;
    return showModalBottomSheet<T>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        final t = sheetCtx.olText;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            OlSpace.xl,
            0,
            OlSpace.xl,
            OlSpace.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: t.heading.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: OlSpace.sm),
                Text(message, style: t.body.copyWith(color: sheetCtx.ol.muted)),
              ],
              if (child != null) ...[const SizedBox(height: OlSpace.md), child],
              if (refId != null) ...[
                const SizedBox(height: OlSpace.sm),
                Text(
                  'Ref: $refId',
                  style: t.mono.copyWith(
                    fontSize: 12,
                    color: sheetCtx.ol.faint,
                  ),
                ),
              ],
              for (final a in actions) ...[
                const SizedBox(height: OlSpace.sm),
                OlButton(
                  label: a.label,
                  variant: a.variant,
                  onPressed: () => Navigator.of(sheetCtx).pop(a.value),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum _ToastKind { success, info, error }

class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.kind,
    required this.message,
    required this.messenger,
    this.refId,
    this.action,
  });

  final _ToastKind kind;
  final String message;
  final String? refId;
  final FeedbackAction? action;
  final ScaffoldMessengerState messenger;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final (OlIconData icon, Color color) = switch (kind) {
      _ToastKind.success => (OlIcons.check, const Color(0xFF4ADE80)),
      _ToastKind.info => (OlIcons.info, const Color(0xFF7DD3FC)),
      _ToastKind.error => (OlIcons.error, const Color(0xFFF87171)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          OlIcon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (refId != null)
                  Text(
                    'Ref: $refId',
                    style: t.mono.copyWith(
                      fontSize: 11.5,
                      color: const Color(0xFF9DB3C4),
                    ),
                  ),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7DD3FC),
                minimumSize: const Size(48, 40),
                textStyle: t.button.copyWith(fontSize: 14),
              ),
              onPressed: () {
                messenger.hideCurrentSnackBar();
                action!.onPressed();
              },
              child: Text(action!.label),
            ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.spec});
  final ConfirmSpec spec;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final t = context.olText;
    final needsReason = s.reasonLabel != null;
    final canConfirm = !needsReason || _reason.text.trim().isNotEmpty;
    void pop(ConfirmChoice c) => Navigator.of(
      context,
    ).pop(ConfirmResult(c, needsReason ? _reason.text.trim() : null));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OlSpace.xl,
          OlSpace.xxl,
          OlSpace.xl,
          18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                s.title,
                style: t.heading.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (s.message.isNotEmpty) ...[
              const SizedBox(height: OlSpace.sm),
              Text(s.message, style: t.body.copyWith(color: context.ol.muted)),
            ],
            if (s.extra != null) ...[
              const SizedBox(height: OlSpace.md),
              s.extra!,
            ],
            if (needsReason) ...[
              const SizedBox(height: OlSpace.md),
              OlTextField(
                label: s.reasonLabel!,
                isRequired: true,
                controller: _reason,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: OlSpace.lg),
            OlButton(
              label: s.confirmLabel,
              variant: s.danger
                  ? OlButtonVariant.danger
                  : OlButtonVariant.primary,
              onPressed: canConfirm ? () => pop(ConfirmChoice.confirm) : null,
            ),
            if (s.alternativeLabel != null) ...[
              const SizedBox(height: OlSpace.sm),
              _DangerTextButton(
                label: s.alternativeLabel!,
                onPressed: () => pop(ConfirmChoice.alternative),
              ),
            ],
            const SizedBox(height: OlSpace.sm),
            OlButton.secondary(
              label: s.cancelLabel,
              onPressed: () => pop(ConfirmChoice.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerTextButton extends StatelessWidget {
  const _DangerTextButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.ol.crit,
      minimumSize: const Size.fromHeight(OlSize.minTouch),
      textStyle: context.olText.button,
    ),
    child: Text(label),
  );
}

/// Menyediakan [AppFeedback] ke subtree. Pakai `context.feedback`.
class FeedbackScope extends InheritedWidget {
  const FeedbackScope({
    super.key,
    required this.feedback,
    required super.child,
  });

  final AppFeedback feedback;

  @override
  bool updateShouldNotify(FeedbackScope oldWidget) =>
      feedback != oldWidget.feedback;
}

extension FeedbackContext on BuildContext {
  AppFeedback get feedback {
    final scope = getInheritedWidgetOfExactType<FeedbackScope>();
    assert(scope != null, 'FeedbackScope tidak ditemukan di atas widget ini.');
    return scope!.feedback;
  }
}

/// Menampilkan banner aktif dari `AppFeedback.banner()` — taruh di atas konten layar.
class FeedbackBannerHost extends StatelessWidget {
  const FeedbackBannerHost({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<BannerSpec>>(
      valueListenable: context.feedback.banners,
      builder: (context, list, _) => AnimatedSize(
        duration: OlMotion.of(context),
        curve: OlMotion.curve,
        alignment: Alignment.topCenter,
        child: Column(
          children: [
            for (final b in list)
              Padding(
                padding: const EdgeInsets.only(bottom: OlSpace.sm),
                child: OlBanner(
                  key: ValueKey(b.id),
                  message: b.message,
                  tone: b.tone,
                  icon: b.icon,
                  actionLabel: b.action?.label,
                  onAction: b.action?.onPressed,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

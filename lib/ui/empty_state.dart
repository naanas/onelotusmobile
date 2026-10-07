import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import 'ol_button.dart';

/// Ilustrasi unDraw yang tersedia (spec D.2, assets/illustrations).
enum OlIllustration {
  emptySchedule('il_empty_schedule'),
  emptySearch('il_empty_search'),
  emptyInbox('il_empty_inbox'),
  emptyExercise('il_empty_exercise'),
  emptyPayment('il_empty_payment'),
  homeVisit('il_home_visit'),
  loginStaff('il_login_staff'),
  maintenance('il_maintenance'),
  offline('il_offline'),
  onboardBooking('il_onboard_booking'),
  onboardExercise('il_onboard_exercise'),
  onboardRecovery('il_onboard_recovery'),
  paymentOnline('il_payment_online'),
  progress('il_progress'),
  reminder('il_reminder'),
  serverError('il_server_error'),
  sessionLocked('il_session_locked'),
  successPayment('il_success_payment'),
  thanksIntake('il_thanks_intake'),
  update('il_update');

  const OlIllustration(this.file);
  final String file;
  String get asset => 'assets/illustrations/$file.svg';
}

/// Ilustrasi dekoratif (tidak dibacakan screen reader).
class OlIllustrationImage extends StatelessWidget {
  const OlIllustrationImage(this.illustration, {super.key, this.width = 200});

  final OlIllustration illustration;
  final double width;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    illustration.asset,
    width: width,
    excludeFromSemantics: true,
  );
}

/// EmptyState (§4): ilustrasi kecil + 1 kalimat + 1 aksi.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.illustration,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final OlIllustration illustration;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OlSpace.xxl,
        vertical: OlSpace.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OlIllustrationImage(illustration, width: 180),
          const SizedBox(height: OlSpace.xl),
          if (title != null) ...[
            Text(title!, style: t.heading, textAlign: TextAlign.center),
            const SizedBox(height: OlSpace.xs),
          ],
          Text(
            message,
            style: t.body.copyWith(color: context.ol.muted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: OlSpace.lg),
            OlButton.secondary(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
              small: true,
            ),
          ],
        ],
      ),
    );
  }
}

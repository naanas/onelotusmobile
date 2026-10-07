import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

enum OlButtonVariant { primary, secondary, text, danger }

/// Tombol One Lotus (spec §4 / D.5): tinggi 52, radius 16.
/// `onPressed == null` → nonaktif. `loading` → spinner + tidak bisa diketuk (cegah kirim ganda, A.0).
class OlButton extends StatelessWidget {
  const OlButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = OlButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.small = false,
    this.expand = true,
  });

  const OlButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.small = false,
    this.expand = true,
  }) : variant = OlButtonVariant.secondary;

  const OlButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.small = false,
    this.expand = false,
  }) : variant = OlButtonVariant.text;

  const OlButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.small = false,
    this.expand = true,
  }) : variant = OlButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final OlButtonVariant variant;
  final OlIconData? icon;
  final bool loading;
  final bool small;
  final bool expand;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final (
      Color bg,
      Color fg,
      List<BoxShadow> shadow,
      Border? border,
    ) = switch (variant) {
      OlButtonVariant.primary => (
        c.brand,
        Colors.white,
        OlShadow.brandButton,
        null,
      ),
      OlButtonVariant.secondary => (
        c.surface,
        c.brandDeep,
        const <BoxShadow>[],
        Border.all(color: c.line, width: 1.5),
      ),
      OlButtonVariant.text => (
        Colors.transparent,
        c.brand,
        const <BoxShadow>[],
        null,
      ),
      OlButtonVariant.danger => (
        c.crit,
        Colors.white,
        OlShadow.critButton,
        null,
      ),
    };
    final disabled = onPressed == null;
    final height = variant == OlButtonVariant.text
        ? OlSize.minTouch
        : (small ? OlSize.buttonSmall : OlSize.button);
    final radius = BorderRadius.circular(
      small ? OlRadius.buttonSmall : OlRadius.button,
    );
    final textStyle = context.olText.button.copyWith(
      color: fg,
      fontSize: small ? 14 : 15,
    );

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        else if (icon != null)
          OlIcon(icon!, size: 20, color: fg),
        if (loading || icon != null) const SizedBox(width: OlSpace.sm),
        Flexible(
          child: Text(
            label,
            style: textStyle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: loading ? '$label, sedang diproses' : null,
      excludeSemantics: loading,
      child: AnimatedOpacity(
        duration: OlMotion.of(context, OlMotion.fast),
        opacity: disabled ? 0.4 : 1,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          width: expand ? double.infinity : null,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: border,
            boxShadow: disabled ? null : shadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: _enabled ? onPressed : null,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: small ? 14 : 18,
                  vertical: 8,
                ),
                child: Center(widthFactor: expand ? null : 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

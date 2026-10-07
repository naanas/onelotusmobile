import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// Baris daftar (`.li`): leading (avatar/ikon) · judul + subjudul · trailing.
class OlListItem extends StatelessWidget {
  const OlListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.divider = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool divider;

  /// Salinan tanpa garis bawah — untuk item terakhir di dalam kartu.
  OlListItem withoutDivider() => OlListItem(
    key: key,
    title: title,
    subtitle: subtitle,
    leading: leading,
    trailing: trailing,
    onTap: onTap,
    showChevron: showChevron,
    divider: false,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: OlSpace.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.bodyStrong),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: t.caption),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: OlSpace.sm),
              trailing!,
            ],
            if (showChevron) ...[
              const SizedBox(width: OlSpace.xs),
              OlIcon(OlIcons.chevronRight, size: 20, color: c.faint),
            ],
          ],
        ),
      ),
    );
  }
}

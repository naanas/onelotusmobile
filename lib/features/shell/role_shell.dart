import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/models/staff_user.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

class TabSpec {
  const TabSpec(this.label, this.icon);
  final String label;
  final OlIconData icon;
}

class FabSpec {
  const FabSpec(this.semanticLabel, this.route);
  final String semanticLabel;
  final String route;
}

/// Tab bar per peran (§3). Label selalu tampil; tab aktif = ikon fill dalam pil `brandSoft`.
/// FAB tengah untuk terapis & kasir, owner tanpa FAB.
class RoleShell extends ConsumerStatefulWidget {
  const RoleShell({
    super.key,
    required this.shell,
    required this.tabs,
    this.fab,
  });

  final StatefulNavigationShell shell;
  final List<TabSpec> tabs;
  final FabSpec? fab;

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends ConsumerState<RoleShell> {
  @override
  void initState() {
    super.initState();
    // UM-01: masuk dengan data lokal saat API tidak terjangkau → banner offline.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(authProvider).offline) {
        context.feedback.error(const AppError(ErrorCode.networkOffline));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final tabs = widget.tabs;
    final fab = widget.fab;
    // Dengan FAB: 2 tab kiri · FAB · 2 tab kanan.
    final half = fab == null ? tabs.length : 2;

    Widget tab(int i) => Expanded(
      child: _TabItem(
        spec: tabs[i],
        selected: widget.shell.currentIndex == i,
        onTap: () {
          if (widget.shell.currentIndex != i) HapticFeedback.selectionClick();
          // Ketuk tab aktif = kembali ke akar tab.
          widget.shell.goBranch(
            i,
            initialLocation: i == widget.shell.currentIndex,
          );
        },
      ),
    );

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: c.line)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x400B1F2E),
              offset: Offset(0, -10),
              blurRadius: 30,
              spreadRadius: -18,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            // Tinggi tetap: tanpa ini Center di FAB memakan seluruh tinggi layar.
            child: SizedBox(
              height: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < half; i++) tab(i),
                  if (fab != null) ...[
                    Expanded(child: _Fab(spec: fab)),
                    for (var i = half; i < tabs.length; i++) tab(i),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final color = selected ? c.brand : c.faint;
    return Semantics(
      selected: selected,
      button: true,
      label: spec.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: OlMotion.of(context, OlMotion.fast),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selected ? c.brandSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(OlRadius.pill),
                ),
                child: OlIcon(
                  spec.icon,
                  color: color,
                  weight: selected ? OlIconWeight.fill : OlIconWeight.regular,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.olText.caption.copyWith(
                  fontSize: 11.5,
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.spec});
  final FabSpec spec;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -18),
        child: Semantics(
          button: true,
          label: spec.semanticLabel,
          excludeSemantics: true,
          child: Container(
            width: OlSize.fab + 12,
            height: OlSize.fab + 12,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
            child: Material(
              color: c.brand,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(spec.route);
                },
                child: Ink(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xD90277B5),
                        offset: Offset(0, 14),
                        blurRadius: 24,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: OlIcon(OlIcons.plus, size: 26, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header konteks "Sel, 6 Okt · Klinik Pusat Malang".
String headerContext(WidgetRef ref, DateTime now) {
  final branch = ref.watch(authProvider.select((s) => s.activeBranch));
  final role = ref.watch(authProvider.select((s) => s.activeRole));
  final parts = <String>[
    Fmt.dayShort(now),
    if (branch != null) branch.name,
    if (role == Role.owner && branch == null) 'semua cabang',
  ];
  return parts.join(' · ');
}

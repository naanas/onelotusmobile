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
      bottomNavigationBar: _TabBar(
        fab: fab,
        children: [
          for (var i = 0; i < half; i++) tab(i),
          // Ruang kosong selebar satu tab di bawah FAB.
          if (fab != null) ...[
            const Expanded(child: SizedBox()),
            for (var i = half; i < tabs.length; i++) tab(i),
          ],
        ],
      ),
    );
  }
}

/// Bar bawah: latar putih opak (bayangan tidak tembus), FAB menumpuk di tengah atas.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.children, this.fab});

  final List<Widget> children;
  final FabSpec? fab;

  static const _height = 60.0;
  static const _fabRise = 22.0;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        // Hanya garis atas: bayangan ke atas akan terpotong di ruang FAB.
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: SizedBox(
            height: _height,
            child: Row(children: children),
          ),
        ),
      ),
    );
    if (fab == null) return bar;
    // FAB menonjol 22dp di atas bar. Ruang itu ikut dihitung dalam ukuran widget
    // (transparan) agar seluruh FAB bisa diketuk — hit-test tidak menjangkau luar batas.
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _fabRise),
          child: bar,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: _Fab(spec: fab!)),
        ),
      ],
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
    final duration = OlMotion.of(context, OlMotion.normal);
    return Semantics(
      selected: selected,
      button: true,
      label: spec.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightColor: Colors.transparent,
        splashColor: c.brandSoft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: duration,
              curve: OlMotion.curve,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 18 : 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? c.brandSoft
                    : c.brandSoft.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(OlRadius.pill),
              ),
              // Ikon regular → fill dengan sedikit "pop".
              child: AnimatedSwitcher(
                duration: duration,
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.0).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: OlIcon(
                  spec.icon,
                  key: ValueKey(selected),
                  color: color,
                  weight: selected ? OlIconWeight.fill : OlIconWeight.regular,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: duration,
              style: context.olText.caption.copyWith(
                fontSize: 11.5,
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// FAB tengah (D.5): lingkaran 56dp, cincin putih 6dp, bayangan brand lembut.
class _Fab extends StatefulWidget {
  const _Fab({required this.spec});
  final FabSpec spec;

  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    return Semantics(
      button: true,
      label: widget.spec.semanticLabel,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: OlMotion.of(context, OlMotion.fast),
        curve: OlMotion.curve,
        child: Container(
          width: OlSize.fab + 12,
          height: OlSize.fab + 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface,
            // Bayangan netral tipis: cincin putih tetap terpisah dari latar halaman
            // tanpa "ekor" biru di atas bar putih.
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0B1F2E),
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Material(
            color: c.brand,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onHighlightChanged: (v) => setState(() => _pressed = v),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(widget.spec.route);
              },
              child: const Center(
                child: OlIcon(OlIcons.plus, size: 26, color: Colors.white),
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

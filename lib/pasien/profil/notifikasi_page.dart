import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';

/// PS-17 Notifikasi pasien + pengaturan per jenis (jadwal, latihan, promo).
class NotifikasiPasienPage extends StatefulWidget {
  const NotifikasiPasienPage({super.key});

  @override
  State<NotifikasiPasienPage> createState() => _NotifikasiPasienPageState();
}

class _NotifikasiPasienPageState extends State<NotifikasiPasienPage> {
  bool _unread = true;
  final _prefs = {
    'Pengingat jadwal': true,
    'Waktunya latihan': true,
    'Promo & tips': false,
  };

  Future<void> _settings() => context.feedback.formSheet<void>(
    title: 'Pengaturan notifikasi',
    builder: (ctx, close) => StatefulBuilder(
      builder: (ctx, set) => Column(
        children: [
          for (final k in _prefs.keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(k, style: ctx.olText.body)),
                  OlToggle(
                    value: _prefs[k]!,
                    semanticLabel: k,
                    onChanged: (v) {
                      set(() => _prefs[k] = v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: OlSpace.md),
          OlButton(label: 'Selesai', onPressed: () => close(null)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    OlListItem item(
      OlIconData icon,
      Color fg,
      Color bg,
      String title,
      String sub,
      String when, {
      bool unread = false,
      VoidCallback? onTap,
    }) => OlListItem(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: OlIcon(icon, color: fg, size: 22),
      ),
      title: title,
      subtitle: sub,
      trailing: unread
          ? Semantics(
              label: 'Belum dibaca',
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: c.brand,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : Text(when, style: context.olText.body.copyWith(color: c.muted)),
      onTap: onTap,
    );

    return OlDetailScaffold(
      title: 'Notifikasi',
      actions: [
        OlIconButton(
          icon: OlIcons.settings,
          semanticLabel: 'Pengaturan notifikasi',
          onPressed: _settings,
        ),
      ],
      children: [
        const OlOverline('HARI INI'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              item(
                OlIcons.checkCircle,
                c.brand,
                c.brandSoft,
                'Booking diterima',
                'Kam 8 Okt pukul 16.00 bersama Dimas',
                '09.12',
                unread: _unread,
                onTap: () {
                  setState(() => _unread = false);
                  context.push(PRoutes.jadwal);
                },
              ),
              item(
                OlIcons.exercise,
                c.ok,
                c.okSoft,
                'Waktunya latihan',
                '2 latihan belum selesai hari ini',
                '07.00',
                onTap: () => context.go(PRoutes.latihan),
              ).withoutDivider(),
            ],
          ),
        ),
        const OlOverline('MINGGU INI'),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              item(
                OlIcons.report,
                c.muted,
                c.surfaceAlt,
                'Ringkasan sesi 6 Okt tersedia',
                'Nyeri turun ke 2',
                'Sel',
                onTap: () => context.push(PRoutes.riwayat),
              ),
              item(
                OlIcons.receipt,
                c.muted,
                c.surfaceAlt,
                'Struk pembayaran',
                'Kinesio tape · Rp35.000',
                'Sel',
                onTap: () => context.push(PRoutes.struk),
              ),
              item(
                OlIcons.voucher,
                c.warn,
                c.warnSoft,
                'Promo paket 10×',
                'Hemat Rp350.000 sampai akhir Oktober',
                'Sen',
                onTap: () => context.push(PRoutes.beliPaket),
              ).withoutDivider(),
            ],
          ),
        ),
      ],
    );
  }
}

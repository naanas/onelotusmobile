import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../pasien_routes.dart';
import '../pasien_session.dart';

/// PS-05 Beranda pasien (§5.8): sapaan, sesi berikutnya (`GET /v1/pasien/sessions`), paket aktif.
/// Progres pemulihan, latihan, tagihan, dan poin menunggu layanannya di server.
class BerandaPage extends ConsumerWidget {
  const BerandaPage({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 11
        ? 'Selamat pagi'
        : h < 15
        ? 'Selamat siang'
        : h < 18
        ? 'Selamat sore'
        : 'Selamat malam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ol;
    final t = context.olText;
    final account = ref.watch(pasienSessionProvider.select((s) => s.account));
    final patient = account?.patient;
    final first = patient?.name.split(' ').first;
    final pkg = patient?.activePackage;
    return OlPageBody(
      heroOverlap: true,
      header: OlAppHeader(
        hero: true,
        title: first == null ? _greeting() : '${_greeting()}, $first',
        context_: patient == null
            ? 'One Lotus'
            : 'One Lotus · ${Fmt.patientNo(patient.number)}',
      ),
      children: [
        const FeedbackBannerHost(),
        const OlSectionHeader(title: 'Jadwal berikutnya'),
        OlAsync<List<PasienSessionItem>>(
          load: () => ref.read(pasienApiProvider).sessions(),
          builder: (context, list, _) {
            if (list.isEmpty) {
              return [
                OlCard(
                  child: EmptyState(
                    illustration: OlIllustration.emptySchedule,
                    title: 'Belum ada jadwal',
                    message:
                        'Buat jadwal terapi di tab Booking.',
                  ),
                ),
              ];
            }
            final s = list.first;
            return [
              OlCard(
                onTap: () => context.push(PRoutes.jadwal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${Fmt.date(s.startAt)} · ${Fmt.time(s.startAt)}',
                            style: t.heading,
                          ),
                        ),
                        OlTag(
                          s.status.label,
                          tone: s.status == SessionStatus.awaitingConfirmation
                              ? OlTagTone.warn
                              : OlTagTone.brand,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.serviceName} · ${s.therapistName}',
                      style: t.body.copyWith(color: c.muted),
                    ),
                    Text(
                      s.homeVisit != null
                          ? 'Home visit · ${s.homeVisit!.address}'
                          : s.branchName,
                      style: t.body.copyWith(color: c.muted),
                    ),
                    if (list.length > 1) ...[
                      const SizedBox(height: 8),
                      Text(
                        '+${list.length - 1} jadwal lain',
                        style: t.bodyStrong.copyWith(color: c.brand),
                      ),
                    ],
                  ],
                ),
              ),
            ];
          },
        ),
        if (pkg != null)
          OlCard(
            onTap: () => context.push(PRoutes.paket),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paket ${pkg.name}', style: t.heading),
                      Text(
                        'Sisa ${pkg.remaining} dari ${pkg.total} sesi'
                        '${pkg.expiresAt == null ? '' : ' · berlaku sampai ${Fmt.dateNoDay(pkg.expiresAt!)}'}',
                        style: t.body.copyWith(
                          color: pkg.almostEmpty ? c.warn : c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                OlIcon(OlIcons.chevronRight, color: c.muted),
              ],
            ),
          ),
      ],
    );
  }
}

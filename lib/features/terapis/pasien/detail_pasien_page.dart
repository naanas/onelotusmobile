import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/ui.dart';
import '../demo_data.dart';

/// TR-05 Detail pasien: profil, tren nyeri, paket, latihan rumah, riwayat sesi,
/// catatan lama (baca-saja), kontak disamarkan untuk terapis (§7, §10).
class DetailPasienPage extends StatelessWidget {
  const DetailPasienPage({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final p = demoPatient(patientId);
    final change = p.painChangePct;

    return OlDetailScaffold(
      title: '',
      actions: [
        OlIconButton(
          icon: OlIcons.more,
          semanticLabel: 'Aksi lain',
          onPressed: () => context.feedback.sheet<void>(
            title: p.name,
            actions: const [
              SheetAction('Tutup', null, variant: OlButtonVariant.secondary),
            ],
          ),
        ),
      ],
      children: [
        // Profil
        Row(
          children: [
            OlAvatar(name: p.name, large: true),
            const SizedBox(width: OlSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(p.name, style: t.title)),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: p.number,
                          style: t.mono.copyWith(color: c.muted),
                        ),
                        TextSpan(
                          text: ' · ${p.age} th · ${p.gender} · ${p.activity}',
                        ),
                      ],
                    ),
                    style: t.body.copyWith(color: c.muted),
                  ),
                  Text(
                    'TB ${p.height} cm · BB ${p.weight} kg',
                    style: t.body.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (p.medicalAlert != null)
          OlBanner(tone: OlBannerTone.crit, message: p.medicalAlert!),
        // Cedera utama + tren nyeri
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.injury,
                      style: t.heading.copyWith(fontSize: 17),
                    ),
                  ),
                  if (p.pain.length > 1)
                    OlTag(
                      '${change > 0 ? '+' : ''}$change%',
                      tone: change <= 0 ? OlTagTone.ok : OlTagTone.crit,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tren nyeri ${p.pain.length} sesi (sebelum sesi)',
                style: t.caption.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              PainTrendChart(
                values: p.pain,
                startLabel: p.painFrom,
                endLabel: p.painTo,
              ),
            ],
          ),
        ),
        // Paket & latihan
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: OlCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paket aktif',
                        style: t.caption.copyWith(fontSize: 13),
                      ),
                      Text(
                        p.packageName ?? 'Tidak ada',
                        style: t.bodyStrong.copyWith(fontSize: 15),
                      ),
                      if (p.packageLeft != null) ...[
                        const SizedBox(height: 6),
                        OlTag(
                          'Sisa ${p.packageLeft} sesi',
                          tone: p.packageLeft! <= 1
                              ? OlTagTone.warn
                              : OlTagTone.brand,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: OlCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latihan rumah',
                        style: t.caption.copyWith(fontSize: 13),
                      ),
                      Text(
                        p.exerciseProgram ?? 'Belum ada',
                        style: t.bodyStrong.copyWith(fontSize: 15),
                      ),
                      if (p.exerciseCompliance != null)
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Kepatuhan '),
                              TextSpan(
                                text: '${p.exerciseCompliance}%',
                                style: TextStyle(
                                  color: c.ok,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(text: ' minggu ini'),
                            ],
                          ),
                          style: t.body.copyWith(color: c.muted),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        OlSectionHeader(
          title: 'Riwayat sesi',
          actionLabel: 'Kirim latihan',
          onAction: () => context.push(Routes.terapisKirimLatihan(p.id)),
        ),
        OlCard(
          padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
          child: Column(
            children: [
              for (final s in p.sessions)
                InkWell(
                  onTap: () => context.push(Routes.terapisSesi(s.sessionId)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.line)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 76,
                          child: Text(
                            s.date,
                            style: t.mono.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: t.body.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                s.caption,
                                style: t.body.copyWith(color: c.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (p.moreSessions > 0)
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: c.muted,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    'Muat ${p.moreSessions} sesi lagi',
                    style: t.body,
                  ),
                )
              else
                const SizedBox(height: 4),
            ],
          ),
        ),
        // Catatan sistem lama — ditampilkan apa adanya (§5.3)
        Container(
          padding: const EdgeInsets.all(OlSpace.lg),
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(OlRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Catatan lama', style: t.heading)),
                  const OlTag('Sistem lama · baca-saja', tone: OlTagTone.muted),
                ],
              ),
              const SizedBox(height: 8),
              Text(p.legacy, style: t.body.copyWith(color: c.muted)),
            ],
          ),
        ),
        // Kontak: terapis tidak melihat nomor lengkap (§7)
        OlCard(
          child: Row(
            children: [
              OlIcon(OlIcons.phone, color: c.muted),
              const SizedBox(width: OlSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kontak pasien',
                      style: t.bodyStrong.copyWith(fontSize: 15),
                    ),
                    Text(
                      'Nomor disamarkan ·',
                      style: t.body.copyWith(color: c.muted),
                    ),
                    Text(p.maskedPhone, style: t.mono.copyWith(color: c.muted)),
                  ],
                ),
              ),
              OlButton.secondary(
                label: 'Hubungi via klinik',
                small: true,
                expand: false,
                onPressed: () => context.feedback.success(
                  'Permintaan menghubungi pasien dikirim ke front desk.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

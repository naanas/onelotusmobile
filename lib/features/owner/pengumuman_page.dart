import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/billing_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../kasir/billing_common.dart';
import 'owner_forms.dart';

const _roleLabels = {'therapist': 'Terapis', 'cashier': 'Kasir', 'admin': 'Admin', 'owner': 'Owner'};

/// OW-16 Pengumuman staf: judul, isi, penerima (peran), kirim sekarang atau dijadwalkan. Muncul di pusat notifikasi staf.
class PengumumanPage extends ConsumerStatefulWidget {
  const PengumumanPage({super.key});

  @override
  ConsumerState<PengumumanPage> createState() => _PengumumanPageState();
}

class _PengumumanPageState extends ConsumerState<PengumumanPage> {
  int _gen = 0;

  Future<void> _create() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final roles = <String>{'therapist', 'cashier'};
    var later = false;
    var at = DateTime.now().add(const Duration(days: 1));
    final ok = await formSheet(
      context,
      title: 'Pengumuman baru',
      confirm: 'Kirim',
      fields: (set) => [
        OlTextField(label: 'Judul', controller: title, isRequired: true),
        OlTextField(label: 'Isi', controller: body, maxLines: 4, isRequired: true),
        Wrap(
          spacing: OlSpace.sm,
          children: [
            for (final MapEntry(:key, :value) in _roleLabels.entries)
              OlChip(label: value, small: true, selected: roles.contains(key), onTap: () => set(() => roles.contains(key) ? roles.remove(key) : roles.add(key))),
          ],
        ),
        OlSegmented<bool>(segments: const {false: 'Kirim sekarang', true: 'Jadwalkan'}, value: later, onChanged: (v) => set(() => later = v)),
        if (later) OwDateRow(label: 'Tanggal kirim (09.00)', value: at, first: DateTime.now(), onChanged: (d) => set(() => at = d)),
      ],
    );
    if (!ok || !mounted) return;
    if (roles.isEmpty) return context.feedback.info('Pilih minimal satu penerima.');
    final r = await runApi(
      context,
      () => ref.read(billingApiProvider).createAnnouncement({
        'title': title.text.trim(),
        'body': body.text.trim(),
        'roles': roles.toList(),
        if (later) 'send_at': DateTime(at.year, at.month, at.day, 9).toUtc().toIso8601String(),
      }),
    );
    if (r == null || !mounted) return;
    context.feedback.success(later ? 'Pengumuman dijadwalkan.' : 'Pengumuman dikirim.');
    setState(() => _gen++);
  }

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: 'Pengumuman',
    foot: [OlButton(label: 'Buat pengumuman', icon: OlIcons.plus, onPressed: _create)],
    children: [
      OlAsync<List<AnnouncementV>>(
        key: ValueKey(_gen),
        load: ref.read(billingApiProvider).announcements,
        builder: (context, list, _) {
          final c = context.ol;
          final t = context.olText;
          if (list.isEmpty) {
            return const [OlCard(child: EmptyState(illustration: OlIllustration.emptyInbox, title: 'Belum ada pengumuman', message: 'Pengumuman muncul di notifikasi staf.'))];
          }
          return [
            for (final a in list)
              OlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: t.heading),
                    const SizedBox(height: OlSpace.xs),
                    Text(a.body, style: t.body),
                    const SizedBox(height: OlSpace.sm),
                    Text(
                      [
                        a.roles.map((r) => _roleLabels[r] ?? r).join(', '),
                        if (a.sendAt != null) (a.sendAt!.isAfter(DateTime.now()) ? 'dijadwalkan ' : '') + Fmt.dayShort(a.sendAt!),
                      ].join(' · '),
                      style: t.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
          ];
        },
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Tanggal sebagai `YYYY-MM-DD` untuk isian `date` di API.
String isoDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Baris pilih tanggal di dalam [formSheet].
class OwDateRow extends StatelessWidget {
  const OwDateRow({super.key, required this.label, required this.value, required this.onChanged, this.first});

  final String label;
  final DateTime value;
  final DateTime? first;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => OlListItem(
    title: label,
    subtitle: Fmt.date(value),
    trailing: OlIcon(OlIcons.calendar, color: context.ol.muted),
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: first ?? DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 3 * 365)),
      );
      if (d != null) onChanged(d);
    },
  );
}

/// Kartu daftar sederhana (judul, keterangan, kanan) untuk layar pengaturan owner.
class OwListCard<T> extends StatelessWidget {
  const OwListCard({super.key, required this.items, required this.title, this.subtitle, this.trailing, this.onTap});

  final List<T> items;
  final String Function(T) title;
  final String? Function(T)? subtitle;
  final Widget? Function(T)? trailing;
  final void Function(T)? onTap;

  @override
  Widget build(BuildContext context) => OlCard(
    padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
    child: Column(
      children: [
        for (final (n, it) in items.indexed)
          OlListItem(
            title: title(it),
            subtitle: subtitle?.call(it),
            trailing: trailing?.call(it),
            divider: n < items.length - 1,
            onTap: onTap == null ? null : () => onTap!(it),
          ),
      ],
    ),
  );
}

/// Catatan aturan yang menunggu workshop mitra (§16): owner mengisi sendiri, aplikasi tidak mengarang.
class OwWorkshopNote extends StatelessWidget {
  const OwWorkshopNote(this.topic, {super.key});
  final String topic;

  @override
  Widget build(BuildContext context) => OlBanner(
    message: 'Aturan $topic belum final dari workshop mitra. Angka di sini persis yang owner isi, tidak ada nilai bawaan.',
    tone: OlBannerTone.info,
  );
}

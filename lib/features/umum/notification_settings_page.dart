import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// UM-13 Pengaturan notifikasi per jenis + jam tenang.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _on = {
    'Sesi baru, berubah, batal': true,
    'Pasien hadir': true,
    'Balasan program latihan': false,
  };
  bool _quiet = true;
  String _from = '21.00';
  String _to = '07.00';

  Future<void> _pickTime(bool from) async {
    final current = (from ? _from : _to).split('.');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(current[0]),
        minute: int.parse(current[1]),
      ),
    );
    if (picked == null) return;
    final v =
        '${picked.hour.toString().padLeft(2, '0')}.${picked.minute.toString().padLeft(2, '0')}';
    setState(() => from ? _from = v : _to = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    Widget row(
      String title, {
      String? subtitle,
      required bool value,
      ValueChanged<bool>? onChanged,
      bool divider = true,
    }) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle, style: t.body.copyWith(color: c.muted)),
              ],
            ),
          ),
          OlToggle(semanticLabel: title, value: value, onChanged: onChanged),
        ],
      ),
    );
    Widget timeBox(String v, VoidCallback onTap, String label) => Expanded(
      child: Semantics(
        container: true,
        button: true,
        label: '$label $v',
        excludeSemantics: true,
        child: InkWell(
          onTap: _quiet ? onTap : null,
          borderRadius: BorderRadius.circular(OlRadius.input),
          child: Container(
            height: OlSize.input,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OlRadius.input),
              border: Border.all(color: c.line, width: 1.5),
            ),
            child: Text(
              v,
              style: t.body.copyWith(
                fontSize: 15,
                color: _quiet ? c.fg : c.muted,
              ),
            ),
          ),
        ),
      ),
    );

    return OlDetailScaffold(
      title: 'Pengaturan notifikasi',
      children: [
        const OlOverline('Jadwal & sesi'),
        OlCard(
          padding: const EdgeInsets.symmetric(
            horizontal: OlSpace.lg,
            vertical: 4,
          ),
          child: Column(
            children: [
              for (final (i, e) in _on.entries.indexed)
                row(
                  e.key,
                  value: e.value,
                  divider: i < _on.length - 1,
                  onChanged: (v) => setState(() => _on[e.key] = v),
                ),
            ],
          ),
        ),
        const OlOverline('Akun & keamanan'),
        OlCard(
          padding: const EdgeInsets.symmetric(
            horizontal: OlSpace.lg,
            vertical: 4,
          ),
          child: Column(
            children: [
              row(
                'Persetujuan cuti & komisi',
                subtitle: 'Wajib, tidak bisa dimatikan',
                value: true,
              ),
              row(
                'Login dari perangkat baru',
                subtitle: 'Wajib, tidak bisa dimatikan',
                value: true,
                divider: false,
              ),
            ],
          ),
        ),
        const OlOverline('Jam tenang'),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row(
                'Aktifkan jam tenang',
                value: _quiet,
                divider: false,
                onChanged: (v) => setState(() => _quiet = v),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  timeBox(_from, () => _pickTime(true), 'Mulai'),
                  const SizedBox(width: OlSpace.md),
                  timeBox(_to, () => _pickTime(false), 'Selesai'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Notifikasi mendesak (pasien hadir, sesi dibatalkan) tetap berbunyi.',
                style: t.body.copyWith(color: c.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

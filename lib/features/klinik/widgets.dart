import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'klinik_api.dart';
import 'klinik_models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

final monthFmt = DateFormat('MMMM yyyy', 'id');
final dateFmt = DateFormat('dd-MM-yyyy', 'id');

/// Tanggal gaya Laravel (dd-mm-yyyy) atau "-".
String tgl(DateTime? d) => d == null ? '-' : dateFmt.format(d);

/// Pemilih bulan ‹ November 2026 › (tidak bisa melewati bulan ini). Nama bulan bergeser searah perpindahan
/// (mundur → dari kiri, maju → dari kanan).
class MonthSwitcher extends StatefulWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  State<MonthSwitcher> createState() => _MonthSwitcherState();
}

class _MonthSwitcherState extends State<MonthSwitcher> {
  /// 1 = maju (bulan baru masuk dari kanan), -1 = mundur.
  int _dir = 1;

  @override
  void didUpdateWidget(MonthSwitcher old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _dir = widget.month.isAfter(old.month) ? 1 : -1;
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final onChanged = widget.onChanged;
    final now = DateTime.now();
    final atLatest = month.year == now.year && month.month == now.month;
    return OlCard(
      child: Row(
        children: [
          OlIconButton(
            icon: OlIcons.back,
            semanticLabel: 'Bulan sebelumnya',
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(OlRadius.input),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: month,
                  firstDate: DateTime(2015),
                  lastDate: DateTime(now.year, now.month + 1, 0),
                  initialDatePickerMode: DatePickerMode.year,
                  helpText: 'Pilih bulan',
                );
                if (picked != null) {
                  onChanged(DateTime(picked.year, picked.month));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: OlMotion.of(context, const Duration(milliseconds: 220)),
                    switchInCurve: OlMotion.curve,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, a) {
                      final incoming = child.key == ValueKey(month);
                      final from = Offset(0.35 * _dir * (incoming ? 1 : -1), 0);
                      return FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: from, end: Offset.zero).animate(a),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      monthFmt.format(month),
                      key: ValueKey(month),
                      textAlign: TextAlign.center,
                      style: context.olText.heading,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: atLatest ? 0.3 : 1,
            duration: OlMotion.of(context, OlMotion.normal),
            child: OlIconButton(
              icon: OlIcons.chevronRight,
              semanticLabel: 'Bulan berikutnya',
              onPressed: atLatest ? null : () => onChanged(DateTime(month.year, month.month + 1)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Unduh Excel satu bulan lalu buka lembar bagikan (simpan ke Files / kirim WhatsApp / Drive).
Future<void> exportExcel(BuildContext context, WidgetRef ref, DateTime month) async {
  try {
    final bytes = await ref.read(klinikApiProvider).export(month);
    final dir = await getTemporaryDirectory();
    final name = '${month.month.toString().padLeft(2, '0')}-${month.year}_data_pasien.xlsx';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        title: 'Data pasien ${monthFmt.format(month)}',
      ),
    );
  } on AppError catch (e) {
    if (context.mounted) {
      if (e.type == ErrorCode.notFound) {
        context.feedback.info(e.message);
      } else {
        context.feedback.error(e);
      }
    }
  } on FileSystemException {
    if (context.mounted) {
      context.feedback.info('File Excel gagal disimpan di HP.');
    }
  }
}

/// Baris "Label: nilai" ringkas.
class LabelValue extends StatelessWidget {
  const LabelValue(this.label, this.value, {super.key});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: context.ol.muted),
            ),
            TextSpan(text: v),
          ],
        ),
        style: context.olText.body,
      ),
    );
  }
}

/// Konfirmasi hapus standar.
Future<bool> confirmHapus(BuildContext context, {required String title, required String message}) =>
    context.feedback.confirm(ConfirmSpec(title: title, message: message, confirmLabel: 'Hapus'));

String nomorPasien(int? n) => n == null ? 'Belum bernomor' : 'No. $n';

String jenisKelamin(String g) => genderLabel(g);

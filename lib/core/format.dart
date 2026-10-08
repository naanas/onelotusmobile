import 'package:intl/intl.dart';

/// Format tampilan (Lampiran A.0): `Sel, 6 Okt 2026`, `09.00`, `Rp450.000`, `#0412`.
abstract final class Fmt {
  static final _dayShort = DateFormat('EEE, d MMM', 'id_ID');
  static final _dateFull = DateFormat('EEE, d MMM y', 'id_ID');
  static final _dateNoDay = DateFormat('d MMM y', 'id_ID');
  static final _time = DateFormat('HH.mm', 'id_ID');
  static final _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String dayShort(DateTime d) => _dayShort.format(d);
  static String date(DateTime d) => _dateFull.format(d);
  static String dateNoDay(DateTime d) => _dateNoDay.format(d);
  static String time(DateTime d) => _time.format(d);
  static String money(num v) => _money.format(v).replaceAll(' ', '');
  static String patientNo(int n) => '#${n.toString().padLeft(4, '0')}';

  /// Hitung mundur `04:32`.
  static String countdown(Duration d) {
    final s = d.inSeconds.clamp(0, 359999);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

const kAppVersion = '1.0.0';

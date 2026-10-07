// Dibangkitkan dari assets/icons/_index.json (spec Lampiran D.1).
// Hanya ikon di daftar ini yang boleh dipakai di aplikasi.
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum OlIconWeight { regular, fill, duotone }

class OlIconData {
  const OlIconData(this.name, this.regular, this.fill, this.duotone);

  final String name;
  final IconData regular;
  final IconData fill;
  final IconData duotone;

  IconData of(OlIconWeight weight) => switch (weight) {
    OlIconWeight.regular => regular,
    OlIconWeight.fill => fill,
    OlIconWeight.duotone => duotone,
  };
}

/// Ikon One Lotus (Phosphor). Pakai: `OlIcon(OlIcons.calendar, weight: OlIconWeight.fill)`.
class OlIcon extends StatelessWidget {
  const OlIcon(
    this.icon, {
    super.key,
    this.weight = OlIconWeight.regular,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final OlIconData icon;
  final OlIconWeight weight;
  final double size;
  final Color? color;

  /// Wajib diisi bila ikon berdiri sendiri tanpa label teks (spec D.0).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => PhosphorIcon(
    icon.of(weight),
    size: size,
    color: color,
    semanticLabel: semanticLabel,
  );
}

abstract final class OlIcons {
  static const home = OlIconData(
    'home',
    PhosphorIconsRegular.house,
    PhosphorIconsFill.house,
    PhosphorIconsDuotone.house,
  );
  static const calendar = OlIconData(
    'calendar',
    PhosphorIconsRegular.calendarBlank,
    PhosphorIconsFill.calendarBlank,
    PhosphorIconsDuotone.calendarBlank,
  );
  static const calendarWeek = OlIconData(
    'calendar_week',
    PhosphorIconsRegular.calendarDots,
    PhosphorIconsFill.calendarDots,
    PhosphorIconsDuotone.calendarDots,
  );
  static const calendarPlus = OlIconData(
    'calendar_plus',
    PhosphorIconsRegular.calendarPlus,
    PhosphorIconsFill.calendarPlus,
    PhosphorIconsDuotone.calendarPlus,
  );
  static const users = OlIconData(
    'users',
    PhosphorIconsRegular.users,
    PhosphorIconsFill.users,
    PhosphorIconsDuotone.users,
  );
  static const user = OlIconData(
    'user',
    PhosphorIconsRegular.user,
    PhosphorIconsFill.user,
    PhosphorIconsDuotone.user,
  );
  static const history = OlIconData(
    'history',
    PhosphorIconsRegular.clockCounterClockwise,
    PhosphorIconsFill.clockCounterClockwise,
    PhosphorIconsDuotone.clockCounterClockwise,
  );
  static const queue = OlIconData(
    'queue',
    PhosphorIconsRegular.queue,
    PhosphorIconsFill.queue,
    PhosphorIconsDuotone.queue,
  );
  static const receipt = OlIconData(
    'receipt',
    PhosphorIconsRegular.receipt,
    PhosphorIconsFill.receipt,
    PhosphorIconsDuotone.receipt,
  );
  static const chart = OlIconData(
    'chart',
    PhosphorIconsRegular.chartBar,
    PhosphorIconsFill.chartBar,
    PhosphorIconsDuotone.chartBar,
  );
  static const report = OlIconData(
    'report',
    PhosphorIconsRegular.presentationChart,
    PhosphorIconsFill.presentationChart,
    PhosphorIconsDuotone.presentationChart,
  );
  static const exercise = OlIconData(
    'exercise',
    PhosphorIconsRegular.barbell,
    PhosphorIconsFill.barbell,
    PhosphorIconsDuotone.barbell,
  );
  static const grid = OlIconData(
    'grid',
    PhosphorIconsRegular.squaresFour,
    PhosphorIconsFill.squaresFour,
    PhosphorIconsDuotone.squaresFour,
  );
  static const plus = OlIconData(
    'plus',
    PhosphorIconsRegular.plus,
    PhosphorIconsFill.plus,
    PhosphorIconsDuotone.plus,
  );
  static const search = OlIconData(
    'search',
    PhosphorIconsRegular.magnifyingGlass,
    PhosphorIconsFill.magnifyingGlass,
    PhosphorIconsDuotone.magnifyingGlass,
  );
  static const bell = OlIconData(
    'bell',
    PhosphorIconsRegular.bell,
    PhosphorIconsFill.bell,
    PhosphorIconsDuotone.bell,
  );
  static const back = OlIconData(
    'back',
    PhosphorIconsRegular.caretLeft,
    PhosphorIconsFill.caretLeft,
    PhosphorIconsDuotone.caretLeft,
  );
  static const chevronRight = OlIconData(
    'chevron_right',
    PhosphorIconsRegular.caretRight,
    PhosphorIconsFill.caretRight,
    PhosphorIconsDuotone.caretRight,
  );
  static const chevronDown = OlIconData(
    'chevron_down',
    PhosphorIconsRegular.caretDown,
    PhosphorIconsFill.caretDown,
    PhosphorIconsDuotone.caretDown,
  );
  static const close = OlIconData(
    'close',
    PhosphorIconsRegular.x,
    PhosphorIconsFill.x,
    PhosphorIconsDuotone.x,
  );
  static const more = OlIconData(
    'more',
    PhosphorIconsRegular.dotsThree,
    PhosphorIconsFill.dotsThree,
    PhosphorIconsDuotone.dotsThree,
  );
  static const edit = OlIconData(
    'edit',
    PhosphorIconsRegular.pencilSimple,
    PhosphorIconsFill.pencilSimple,
    PhosphorIconsDuotone.pencilSimple,
  );
  static const archive = OlIconData(
    'archive',
    PhosphorIconsRegular.archive,
    PhosphorIconsFill.archive,
    PhosphorIconsDuotone.archive,
  );
  static const filter = OlIconData(
    'filter',
    PhosphorIconsRegular.funnelSimple,
    PhosphorIconsFill.funnelSimple,
    PhosphorIconsDuotone.funnelSimple,
  );
  static const sort = OlIconData(
    'sort',
    PhosphorIconsRegular.arrowsDownUp,
    PhosphorIconsFill.arrowsDownUp,
    PhosphorIconsDuotone.arrowsDownUp,
  );
  static const share = OlIconData(
    'share',
    PhosphorIconsRegular.shareNetwork,
    PhosphorIconsFill.shareNetwork,
    PhosphorIconsDuotone.shareNetwork,
  );
  static const download = OlIconData(
    'download',
    PhosphorIconsRegular.downloadSimple,
    PhosphorIconsFill.downloadSimple,
    PhosphorIconsDuotone.downloadSimple,
  );
  static const upload = OlIconData(
    'upload',
    PhosphorIconsRegular.uploadSimple,
    PhosphorIconsFill.uploadSimple,
    PhosphorIconsDuotone.uploadSimple,
  );
  static const camera = OlIconData(
    'camera',
    PhosphorIconsRegular.camera,
    PhosphorIconsFill.camera,
    PhosphorIconsDuotone.camera,
  );
  static const mic = OlIconData(
    'mic',
    PhosphorIconsRegular.microphone,
    PhosphorIconsFill.microphone,
    PhosphorIconsDuotone.microphone,
  );
  static const attach = OlIconData(
    'attach',
    PhosphorIconsRegular.paperclip,
    PhosphorIconsFill.paperclip,
    PhosphorIconsDuotone.paperclip,
  );
  static const send = OlIconData(
    'send',
    PhosphorIconsRegular.paperPlaneTilt,
    PhosphorIconsFill.paperPlaneTilt,
    PhosphorIconsDuotone.paperPlaneTilt,
  );
  static const refresh = OlIconData(
    'refresh',
    PhosphorIconsRegular.arrowClockwise,
    PhosphorIconsFill.arrowClockwise,
    PhosphorIconsDuotone.arrowClockwise,
  );
  static const copy = OlIconData(
    'copy',
    PhosphorIconsRegular.copy,
    PhosphorIconsFill.copy,
    PhosphorIconsDuotone.copy,
  );
  static const phone = OlIconData(
    'phone',
    PhosphorIconsRegular.phone,
    PhosphorIconsFill.phone,
    PhosphorIconsDuotone.phone,
  );
  static const chat = OlIconData(
    'chat',
    PhosphorIconsRegular.chatCircleDots,
    PhosphorIconsFill.chatCircleDots,
    PhosphorIconsDuotone.chatCircleDots,
  );
  static const print = OlIconData(
    'print',
    PhosphorIconsRegular.printer,
    PhosphorIconsFill.printer,
    PhosphorIconsDuotone.printer,
  );
  static const eye = OlIconData(
    'eye',
    PhosphorIconsRegular.eye,
    PhosphorIconsFill.eye,
    PhosphorIconsDuotone.eye,
  );
  static const eyeOff = OlIconData(
    'eye_off',
    PhosphorIconsRegular.eyeSlash,
    PhosphorIconsFill.eyeSlash,
    PhosphorIconsDuotone.eyeSlash,
  );
  static const logout = OlIconData(
    'logout',
    PhosphorIconsRegular.signOut,
    PhosphorIconsFill.signOut,
    PhosphorIconsDuotone.signOut,
  );
  static const check = OlIconData(
    'check',
    PhosphorIconsRegular.check,
    PhosphorIconsFill.check,
    PhosphorIconsDuotone.check,
  );
  static const checkCircle = OlIconData(
    'check_circle',
    PhosphorIconsRegular.checkCircle,
    PhosphorIconsFill.checkCircle,
    PhosphorIconsDuotone.checkCircle,
  );
  static const alert = OlIconData(
    'alert',
    PhosphorIconsRegular.warning,
    PhosphorIconsFill.warning,
    PhosphorIconsDuotone.warning,
  );
  static const info = OlIconData(
    'info',
    PhosphorIconsRegular.info,
    PhosphorIconsFill.info,
    PhosphorIconsDuotone.info,
  );
  static const error = OlIconData(
    'error',
    PhosphorIconsRegular.xCircle,
    PhosphorIconsFill.xCircle,
    PhosphorIconsDuotone.xCircle,
  );
  static const clock = OlIconData(
    'clock',
    PhosphorIconsRegular.clock,
    PhosphorIconsFill.clock,
    PhosphorIconsDuotone.clock,
  );
  static const lock = OlIconData(
    'lock',
    PhosphorIconsRegular.lockSimple,
    PhosphorIconsFill.lockSimple,
    PhosphorIconsDuotone.lockSimple,
  );
  static const fingerprint = OlIconData(
    'fingerprint',
    PhosphorIconsRegular.fingerprint,
    PhosphorIconsFill.fingerprint,
    PhosphorIconsDuotone.fingerprint,
  );
  static const offline = OlIconData(
    'offline',
    PhosphorIconsRegular.cloudSlash,
    PhosphorIconsFill.cloudSlash,
    PhosphorIconsDuotone.cloudSlash,
  );
  static const sync = OlIconData(
    'sync',
    PhosphorIconsRegular.arrowsClockwise,
    PhosphorIconsFill.arrowsClockwise,
    PhosphorIconsDuotone.arrowsClockwise,
  );
  static const cloudOk = OlIconData(
    'cloud_ok',
    PhosphorIconsRegular.cloudCheck,
    PhosphorIconsFill.cloudCheck,
    PhosphorIconsDuotone.cloudCheck,
  );
  static const cloudAlert = OlIconData(
    'cloud_alert',
    PhosphorIconsRegular.cloudWarning,
    PhosphorIconsFill.cloudWarning,
    PhosphorIconsDuotone.cloudWarning,
  );
  static const settings = OlIconData(
    'settings',
    PhosphorIconsRegular.slidersHorizontal,
    PhosphorIconsFill.slidersHorizontal,
    PhosphorIconsDuotone.slidersHorizontal,
  );
  static const help = OlIconData(
    'help',
    PhosphorIconsRegular.question,
    PhosphorIconsFill.question,
    PhosphorIconsDuotone.question,
  );
  static const body = OlIconData(
    'body',
    PhosphorIconsRegular.person,
    PhosphorIconsFill.person,
    PhosphorIconsDuotone.person,
  );
  static const pain = OlIconData(
    'pain',
    PhosphorIconsRegular.gauge,
    PhosphorIconsFill.gauge,
    PhosphorIconsDuotone.gauge,
  );
  static const hands = OlIconData(
    'hands',
    PhosphorIconsRegular.hand,
    PhosphorIconsFill.hand,
    PhosphorIconsDuotone.hand,
  );
  static const infrared = OlIconData(
    'infrared',
    PhosphorIconsRegular.lamp,
    PhosphorIconsFill.lamp,
    PhosphorIconsDuotone.lamp,
  );
  static const stretch = OlIconData(
    'stretch',
    PhosphorIconsRegular.personSimpleTaiChi,
    PhosphorIconsFill.personSimpleTaiChi,
    PhosphorIconsDuotone.personSimpleTaiChi,
  );
  static const tape = OlIconData(
    'tape',
    PhosphorIconsRegular.bandaids,
    PhosphorIconsFill.bandaids,
    PhosphorIconsDuotone.bandaids,
  );
  static const needle = OlIconData(
    'needle',
    PhosphorIconsRegular.syringe,
    PhosphorIconsFill.syringe,
    PhosphorIconsDuotone.syringe,
  );
  static const xray = OlIconData(
    'xray',
    PhosphorIconsRegular.scan,
    PhosphorIconsFill.scan,
    PhosphorIconsDuotone.scan,
  );
  static const homeVisit = OlIconData(
    'home_visit',
    PhosphorIconsRegular.houseLine,
    PhosphorIconsFill.houseLine,
    PhosphorIconsDuotone.houseLine,
  );
  static const pin = OlIconData(
    'pin',
    PhosphorIconsRegular.mapPin,
    PhosphorIconsFill.mapPin,
    PhosphorIconsDuotone.mapPin,
  );
  static const cash = OlIconData(
    'cash',
    PhosphorIconsRegular.money,
    PhosphorIconsFill.money,
    PhosphorIconsDuotone.money,
  );
  static const qris = OlIconData(
    'qris',
    PhosphorIconsRegular.qrCode,
    PhosphorIconsFill.qrCode,
    PhosphorIconsDuotone.qrCode,
  );
  static const transfer = OlIconData(
    'transfer',
    PhosphorIconsRegular.arrowsLeftRight,
    PhosphorIconsFill.arrowsLeftRight,
    PhosphorIconsDuotone.arrowsLeftRight,
  );
  static const package = OlIconData(
    'package',
    PhosphorIconsRegular.package,
    PhosphorIconsFill.package,
    PhosphorIconsDuotone.package,
  );
  static const points = OlIconData(
    'points',
    PhosphorIconsRegular.star,
    PhosphorIconsFill.star,
    PhosphorIconsDuotone.star,
  );
  static const voucher = OlIconData(
    'voucher',
    PhosphorIconsRegular.ticket,
    PhosphorIconsFill.ticket,
    PhosphorIconsDuotone.ticket,
  );
  static const percent = OlIconData(
    'percent',
    PhosphorIconsRegular.percent,
    PhosphorIconsFill.percent,
    PhosphorIconsDuotone.percent,
  );
  static const branch = OlIconData(
    'branch',
    PhosphorIconsRegular.buildings,
    PhosphorIconsFill.buildings,
    PhosphorIconsDuotone.buildings,
  );

  static const all = <OlIconData>[
    home,
    calendar,
    calendarWeek,
    calendarPlus,
    users,
    user,
    history,
    queue,
    receipt,
    chart,
    report,
    exercise,
    grid,
    plus,
    search,
    bell,
    back,
    chevronRight,
    chevronDown,
    close,
    more,
    edit,
    archive,
    filter,
    sort,
    share,
    download,
    upload,
    camera,
    mic,
    attach,
    send,
    refresh,
    copy,
    phone,
    chat,
    print,
    eye,
    eyeOff,
    logout,
    check,
    checkCircle,
    alert,
    info,
    error,
    clock,
    lock,
    fingerprint,
    offline,
    sync,
    cloudOk,
    cloudAlert,
    settings,
    help,
    body,
    pain,
    hands,
    infrared,
    stretch,
    tape,
    needle,
    xray,
    homeVisit,
    pin,
    cash,
    qris,
    transfer,
    package,
    points,
    voucher,
    percent,
    branch,
  ];
}

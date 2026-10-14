import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/api/one_lotus_api.dart';
import '../../data/models/models.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Filter cepat di atas daftar pasien.
class PatientListFilter {
  const PatientListFilter(this.label, this.filter);
  final String label;
  final PatientFilter filter;
}

/// "Hari ini", "3 hari lalu", "12 Agu 2026".
String lastVisitLabel(DateTime? at, DateTime now) {
  if (at == null) return 'Belum ada kunjungan';
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) return 'Kunjungan hari ini';
  if (days == 1) return 'Kunjungan kemarin';
  if (days < 30) return 'Kunjungan $days hari lalu';
  return 'Kunjungan ${Fmt.dateNoDay(at)}';
}

int? daysAway(Patient p, DateTime now) =>
    p.lastVisitAt == null ? null : now.difference(p.lastVisitAt!).inDays;

/// Daftar pasien dari `GET /v1/patients`: cari (nama, nomor, 4 digit HP), filter, 20 per halaman.
class PatientList extends ConsumerStatefulWidget {
  const PatientList({
    super.key,
    required this.onTap,
    this.mine = false,
    this.filters = const [],
    this.hint = 'Cari nama, #nomor, atau 4 digit HP',
  });

  final ValueChanged<Patient> onTap;

  /// Hanya pasien yang pernah ditangani terapis login (TR-06).
  final bool mine;
  final List<PatientListFilter> filters;
  final String hint;

  @override
  ConsumerState<PatientList> createState() => _PatientListState();
}

class _PatientListState extends ConsumerState<PatientList> {
  String _query = '';
  int _filter = 0;
  final List<Patient> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  int _total = 0;
  AppError? _error;
  Timer? _debounce;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  PatientFilter get _activeFilter => widget.filters.isEmpty
      ? const PatientFilter()
      : widget.filters[_filter].filter;

  void _reload() {
    _gen++;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    _more();
  }

  Future<void> _more() async {
    if (_loading || !_hasMore) return;
    final gen = _gen;
    setState(() => _loading = true);
    try {
      final r = await ref
          .read(oneLotusApiProvider)
          .patients(
            query: _query,
            page: _page + 1,
            mine: widget.mine,
            filter: _activeFilter,
          );
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(r.items);
        _page = r.page;
        _hasMore = r.hasMore;
        _total = r.total;
      });
    } on AppError catch (e) {
      if (mounted && gen == _gen) setState(() => _error = e);
    } finally {
      if (mounted && gen == _gen) setState(() => _loading = false);
    }
  }

  void _search(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = v.trim();
      _reload();
    });
  }

  Widget? _trailing(Patient p, DateTime now) {
    if (p.archivedAt != null) {
      return const OlTag('Arsip', tone: OlTagTone.muted);
    }
    final away = daysAway(p, now);
    if (away != null && away > 30) {
      return OlTag('$away hari', tone: OlTagTone.crit);
    }
    final pkg = p.activePackage;
    if (pkg != null && pkg.almostEmpty) {
      return OlTag('Sisa ${pkg.remaining}', tone: OlTagTone.warn);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OlSearchField(hint: widget.hint, onChanged: _search),
        if (widget.filters.isNotEmpty) ...[
          const SizedBox(height: OlSpace.md),
          Wrap(
            spacing: OlSpace.sm,
            runSpacing: OlSpace.sm,
            children: [
              for (final (i, f) in widget.filters.indexed)
                OlChip(
                  label: f.label,
                  selected: _filter == i,
                  onTap: () {
                    setState(() => _filter = i);
                    _reload();
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: OlSpace.md),
        if (_error != null && _items.isEmpty)
          OlCard(
            child: Column(
              children: [
                Text(
                  _error!.message,
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: context.ol.muted),
                ),
                const SizedBox(height: OlSpace.md),
                OlButton(label: 'Coba lagi', expand: false, onPressed: _reload),
              ],
            ),
          )
        else if (_items.isEmpty && _loading)
          const OlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 180, height: 16),
                SizedBox(height: 10),
                Skeleton(height: 12),
                SizedBox(height: 18),
                Skeleton(width: 150, height: 16),
                SizedBox(height: 10),
                Skeleton(height: 12),
              ],
            ),
          )
        else if (_items.isEmpty)
          OlCard(
            child: EmptyState(
              illustration: OlIllustration.emptySearch,
              title: _query.isEmpty
                  ? 'Belum ada pasien'
                  : 'Pasien tidak ditemukan',
              message: _query.isEmpty
                  ? 'Daftar pasien kosong untuk filter ini.'
                  : 'Coba nama lain, nomor pasien (#0412), atau ubah filter.',
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: OlSpace.sm),
            child: Text('$_total pasien', style: t.caption),
          ),
          OlCard(
            padding: const EdgeInsets.symmetric(horizontal: OlSpace.lg),
            child: Column(
              children: [
                for (final (i, p) in _items.indexed)
                  OlListItem(
                    leading: OlAvatar(name: p.name),
                    title: p.name,
                    subtitle:
                        '${Fmt.patientNo(p.number)} · ${lastVisitLabel(p.lastVisitAt, now)}',
                    trailing: _trailing(p, now),
                    divider: i < _items.length - 1,
                    onTap: () => widget.onTap(p),
                  ),
              ],
            ),
          ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: OlSpace.md),
              child: OlButton.secondary(
                label: _loading ? 'Memuat…' : 'Muat 20 berikutnya',
                onPressed: _loading ? null : _more,
              ),
            ),
        ],
      ],
    );
  }
}

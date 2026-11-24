import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// SearchBar (§4): ikon cari, debounce 300ms, tombol hapus.
class OlSearchField extends StatefulWidget {
  const OlSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
    this.controller,
    this.elevated = false,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  /// Isi bersama (mis. kolom cari di kartu & versi melayang saat digulir).
  final TextEditingController? controller;

  /// Bayangan lembut (dipakai saat melayang di atas konten).
  final bool elevated;

  @override
  State<OlSearchField> createState() => _OlSearchFieldState();
}

class _OlSearchFieldState extends State<OlSearchField> {
  late final TextEditingController _ctrl = widget.controller ?? TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_sync);
  }

  /// Teks diubah dari kolom lain yang berbagi controller → tombol hapus ikut tampil/hilang.
  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_sync);
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => widget.onChanged(v.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(OlRadius.input + 2),
        border: Border.all(color: c.line, width: 1.5),
        boxShadow: widget.elevated
            ? const [BoxShadow(color: Color(0x290B1F2E), blurRadius: 18, offset: Offset(0, 6))]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          OlIcon(OlIcons.search, color: c.muted, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: widget.autofocus,
              onChanged: _changed,
              textInputAction: TextInputAction.search,
              style: t.body.copyWith(fontSize: 15),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: t.body.copyWith(fontSize: 15, color: c.faint),
              ),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            IconButton(
              tooltip: 'Hapus pencarian',
              onPressed: () {
                _ctrl.clear();
                _changed('');
              },
              icon: OlIcon(OlIcons.close, size: 18, color: c.muted),
            ),
        ],
      ),
    );
  }
}

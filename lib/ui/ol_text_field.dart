import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ol_icon.dart';

/// FormField (spec §4): label di atas, penanda wajib `*`, helper, inline error (§12.2), fokus = ring brand.
class OlTextField extends StatefulWidget {
  const OlTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.isRequired = false,
    this.helper,
    this.error,
    this.hint,
    this.suffixText,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.mono = false,
    this.maxLines = 1,
    this.autofillHints,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final bool isRequired;
  final String? helper;

  /// Pesan error inline; null = tidak ada error. Isian tidak pernah dihapus saat error (§12.1).
  final String? error;
  final String? hint;
  final String? suffixText;

  /// Password: menampilkan tombol tampil/sembunyi.
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// Teks isian memakai JetBrains Mono (nominal, nomor).
  final bool mono;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  @override
  State<OlTextField> createState() => _OlTextFieldState();
}

class _OlTextFieldState extends State<OlTextField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late bool _hidden = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final hasError = widget.error != null;
    final focused = _focus.hasFocus;
    final multiline = widget.maxLines > 1;

    final List<BoxShadow> ring = [
      if (hasError)
        BoxShadow(color: c.critSoft, spreadRadius: 4)
      else if (focused)
        BoxShadow(color: c.brandSoft, spreadRadius: 4),
    ];
    final borderColor = hasError ? c.crit : (focused ? c.brand : c.line);
    final inputStyle =
        (widget.mono
                ? t.mono.copyWith(fontSize: 15)
                : t.body.copyWith(fontSize: 15))
            .copyWith(color: widget.enabled ? c.fg : c.muted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: widget.label),
                if (widget.isRequired)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: c.crit),
                  ),
              ],
            ),
            style: t.fieldLabel,
          ),
          const SizedBox(height: 7),
        ],
        AnimatedContainer(
          duration: OlMotion.of(context, OlMotion.fast),
          constraints: BoxConstraints(minHeight: multiline ? 84 : OlSize.input),
          decoration: BoxDecoration(
            color: widget.enabled ? c.surface : const Color(0xFFF7F9FB),
            borderRadius: BorderRadius.circular(OlRadius.input),
            border: Border.all(
              color: borderColor,
              width: focused && !hasError ? 2 : 1.5,
            ),
            boxShadow: ring,
          ),
          padding: EdgeInsets.only(left: 16, right: widget.obscure ? 4 : 16),
          child: Row(
            crossAxisAlignment: multiline
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  initialValue: widget.controller == null
                      ? widget.initialValue
                      : null,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  obscureText: _hidden,
                  obscuringCharacter: '•',
                  keyboardType: multiline
                      ? TextInputType.multiline
                      : widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  onFieldSubmitted: widget.onSubmitted,
                  maxLines: widget.obscure ? 1 : widget.maxLines,
                  minLines: 1,
                  autofillHints: widget.autofillHints,
                  style: inputStyle,
                  cursorColor: c.brand,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: multiline ? 13 : 14,
                    ),
                    hintText: widget.hint,
                    hintStyle: inputStyle.copyWith(color: c.faint),
                  ),
                ),
              ),
              if (widget.suffixText != null)
                Padding(
                  padding: const EdgeInsets.only(left: OlSpace.sm),
                  child: Text(
                    widget.suffixText!,
                    style: t.body.copyWith(fontSize: 15, color: c.muted),
                  ),
                ),
              if (widget.obscure)
                IconButton(
                  onPressed: () => setState(() => _hidden = !_hidden),
                  tooltip: _hidden
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
                  icon: OlIcon(
                    _hidden ? OlIcons.eye : OlIcons.eyeOff,
                    color: c.muted,
                  ),
                ),
            ],
          ),
        ),
        if (hasError || widget.helper != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: hasError,
            child: Text(
              widget.error ?? widget.helper!,
              style: t.caption.copyWith(
                color: hasError ? c.crit : c.muted,
                fontWeight: hasError ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

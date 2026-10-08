import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../theme/app_theme.dart';

/// Format isian rupiah saat diketik: "1230000" → "Rp1.230.000".
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = Fmt.money(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  static int parse(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;
}

/// Isian nominal besar (CashCalculator §4, tutup kas): mono, tebal, fokus = ring brand.
class OlMoneyField extends StatefulWidget {
  const OlMoneyField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.isRequired = false,
    this.large = true,
    this.error,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String? label;
  final bool isRequired;
  final bool large;
  final String? error;

  @override
  State<OlMoneyField> createState() => _OlMoneyFieldState();
}

class _OlMoneyFieldState extends State<OlMoneyField> {
  late final _ctrl = TextEditingController(
    text: widget.value == 0 ? '' : Fmt.money(widget.value),
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(OlMoneyField old) {
    super.didUpdateWidget(old);
    if (RupiahInputFormatter.parse(_ctrl.text) != widget.value) {
      _ctrl.text = widget.value == 0 ? '' : Fmt.money(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    final focused = _focus.hasFocus;
    final hasError = widget.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(OlRadius.input + 2),
            border: Border.all(
              color: hasError ? c.crit : (focused ? c.brand : c.line),
              width: focused ? 2 : 1.5,
            ),
            boxShadow: [
              if (focused || hasError)
                BoxShadow(
                  color: hasError ? c.critSoft : c.brandSoft,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            onChanged: (v) => widget.onChanged(RupiahInputFormatter.parse(v)),
            style: t.mono.copyWith(
              fontSize: widget.large ? 28 : 17,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Rp0',
              hintStyle: t.mono.copyWith(
                fontSize: widget.large ? 28 : 17,
                color: c.faint,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.error!,
            style: t.caption.copyWith(
              color: c.crit,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

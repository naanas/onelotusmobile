import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'owner_widgets.dart';

class _Voucher {
  const _Voucher(
    this.code,
    this.detail,
    this.usage,
    this.until, {
    this.used = 0,
    this.quota,
    this.active = true,
  });

  final String code;
  final String detail;
  final String usage;
  final String until;
  final int used;
  final int? quota;
  final bool active;
}

/// OW-12 Voucher & promo: daftar voucher + pemakaian, buat voucher baru.
class VoucherPage extends StatefulWidget {
  const VoucherPage({super.key});

  @override
  State<VoucherPage> createState() => _VoucherPageState();
}

class _VoucherPageState extends State<VoucherPage> {
  final _items = <_Voucher>[
    const _Voucher(
      'ATLETMLG',
      '15% · min. Rp200.000 · semua layanan cedera',
      '23 / 50 dipakai · potongan Rp1,04 jt',
      's/d 31 Okt',
      used: 23,
      quota: 50,
    ),
    const _Voucher(
      'TEMANLOTUS',
      'Rp50.000 · referral · 1× per pasien',
      '9 dipakai · tanpa kuota total',
      's/d 31 Des',
      used: 9,
    ),
    const _Voucher(
      'AGUSTUS17',
      '17% · Agustus 2026 · 112 dipakai',
      '',
      '',
      active: false,
    ),
  ];
  final _code = TextEditingController(text: 'LEBARAN26');
  final _value = TextEditingController(text: '10');
  bool _percent = true;
  final _formKey = GlobalKey();

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    super.dispose();
  }

  String? get _codeError {
    final c = _code.text.trim().toUpperCase();
    if (c.isEmpty) return null;
    if (_items.any((v) => v.code == c)) return 'Kode sudah dipakai.';
    if (!RegExp(r'^[A-Z0-9]{4,16}$').hasMatch(c)) {
      return '4–16 huruf/angka, tanpa spasi.';
    }
    return null;
  }

  bool get _valid =>
      _code.text.trim().isNotEmpty &&
      _codeError == null &&
      (int.tryParse(_value.text) ?? 0) > 0;

  void _create() {
    final code = _code.text.trim().toUpperCase();
    final n = int.parse(_value.text);
    setState(() {
      _items.insert(
        0,
        _Voucher(
          code,
          _percent ? '$n% · semua layanan' : '${Fmt.money(n)} · semua layanan',
          'belum dipakai',
          's/d 31 Des',
        ),
      );
      _code.clear();
      _value.clear();
    });
    context.feedback.success('Voucher $code aktif.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return OlDetailScaffold(
      title: 'Voucher & promo',
      actions: [
        OlButton(
          label: '+ Voucher',
          small: true,
          expand: false,
          onPressed: () => Scrollable.ensureVisible(
            _formKey.currentContext!,
            duration: OlMotion.of(context, OlMotion.slow),
            curve: OlMotion.curve,
          ),
        ),
      ],
      children: [
        for (final v in _items)
          OwCatalogCard(
            key: ValueKey(v.code),
            title: v.code,
            mono: true,
            detail: v.detail,
            active: v.active,
            statusLabel: v.active ? 'Aktif' : 'Berakhir',
            extra: v.active
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OwProgress(
                        value: v.quota == null
                            ? (v.used / 50)
                            : v.used / v.quota!,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              v.usage,
                              style: t.body.copyWith(
                                fontSize: 14,
                                color: c.muted,
                              ),
                            ),
                          ),
                          Text(
                            v.until,
                            style: t.body.copyWith(
                              fontSize: 14,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : null,
          ),
        OlOverline('VOUCHER BARU', key: _formKey),
        OlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OlTextField(
                label: 'Kode',
                isRequired: true,
                controller: _code,
                error: _codeError,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  TextInputFormatter.withFunction(
                    (_, v) => v.copyWith(text: v.text.toUpperCase()),
                  ),
                ],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: OlSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Tipe', style: t.fieldLabel),
                        const SizedBox(height: 8),
                        OlSegmented<bool>(
                          segments: const {true: '%', false: 'Rp'},
                          value: _percent,
                          onChanged: (v) => setState(() => _percent = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: OlSpace.md),
                  Expanded(
                    child: OlTextField(
                      label: 'Nilai',
                      isRequired: true,
                      controller: _value,
                      suffixText: _percent ? '%' : null,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OlSpace.md),
              OlButton(
                label: 'Buat voucher',
                onPressed: _valid ? _create : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

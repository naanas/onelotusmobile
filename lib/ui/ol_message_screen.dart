import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'empty_state.dart';
import 'ol_foot_bar.dart';

/// Layar pesan penuh (UM-02, UM-03, ST-15): ilustrasi, judul, penjelasan, isi tambahan, tombol bawah.
class OlMessageScreen extends StatelessWidget {
  const OlMessageScreen({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    this.messageSpans,
    this.children = const [],
    this.foot = const [],
  });

  final OlIllustration illustration;
  final String title;
  final String message;

  /// Bila diisi, dipakai sebagai pengganti [message] (mis. jam bergaya mono).
  final List<InlineSpan>? messageSpans;
  final List<Widget> children;
  final List<Widget> foot;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    final c = context.ol;
    final style = t.body.copyWith(fontSize: 16, color: c.muted, height: 1.5);
    return Scaffold(
      body: SafeArea(
        bottom: foot.isEmpty,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OlSpace.xxl + 8,
                    vertical: OlSpace.xxl,
                  ),
                  child: Column(
                    children: [
                      OlIllustrationImage(illustration, width: 240),
                      const SizedBox(height: 28),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: t.title.copyWith(fontSize: 26),
                        ),
                      ),
                      const SizedBox(height: 12),
                      messageSpans == null
                          ? Text(
                              message,
                              textAlign: TextAlign.center,
                              style: style,
                            )
                          : Text.rich(
                              TextSpan(children: messageSpans),
                              textAlign: TextAlign.center,
                              style: style,
                            ),
                      for (final w in children) ...[
                        const SizedBox(height: OlSpace.lg + 4),
                        w,
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (foot.isNotEmpty) OlFootBar(children: foot),
          ],
        ),
      ),
    );
  }
}

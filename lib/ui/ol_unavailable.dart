import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'empty_state.dart';
import 'ol_app_header.dart';
import 'ol_detail_scaffold.dart';
import 'ol_page_body.dart';

/// Fitur yang layanan server-nya belum dibuat. Tidak menampilkan data contoh —
/// cukup menjelaskan apa yang ditunggu (mis. modul pembayaran, keputusan workshop §16).
class OlUnavailable extends StatelessWidget {
  const OlUnavailable({
    super.key,
    required this.feature,
    required this.waitingFor,
    this.illustration = OlIllustration.emptyInbox,
  });

  final String feature;
  final String waitingFor;
  final OlIllustration illustration;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: OlSpace.xl),
    child: EmptyState(
      illustration: illustration,
      title: '$feature belum tersedia',
      message: 'Belum tersambung ke server One Lotus. Menunggu: $waitingFor.',
    ),
  );
}

/// Layar turunan (push) untuk fitur yang belum tersedia.
class OlUnavailablePage extends StatelessWidget {
  const OlUnavailablePage({
    super.key,
    required this.title,
    required this.feature,
    required this.waitingFor,
    this.illustration = OlIllustration.emptyInbox,
  });

  final String title;
  final String feature;
  final String waitingFor;
  final OlIllustration illustration;

  @override
  Widget build(BuildContext context) => OlDetailScaffold(
    title: title,
    children: [
      OlUnavailable(
        feature: feature,
        waitingFor: waitingFor,
        illustration: illustration,
      ),
    ],
  );
}

/// Tab utama untuk fitur yang belum tersedia.
class OlUnavailableTab extends StatelessWidget {
  const OlUnavailableTab({
    super.key,
    required this.title,
    required this.feature,
    required this.waitingFor,
    this.illustration = OlIllustration.emptyInbox,
  });

  final String title;
  final String feature;
  final String waitingFor;
  final OlIllustration illustration;

  @override
  Widget build(BuildContext context) => OlPageBody(
    header: OlAppHeader(title: title),
    children: [
      OlUnavailable(
        feature: feature,
        waitingFor: waitingFor,
        illustration: illustration,
      ),
    ],
  );
}

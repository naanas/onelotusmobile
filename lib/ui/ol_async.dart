import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'feedback/app_error.dart';
import 'ol_button.dart';
import 'ol_card.dart';
import 'skeleton.dart';

/// Memuat data dari server untuk satu layar: skeleton saat memuat, pesan error + "Coba lagi"
/// (ST-03), lalu [builder]. [reload] memuat ulang (mis. setelah aksi berhasil).
class OlAsync<T> extends StatefulWidget {
  const OlAsync({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final List<Widget> Function(BuildContext context, T data, VoidCallback reload)
  builder;

  @override
  State<OlAsync<T>> createState() => _OlAsyncState<T>();
}

class _OlAsyncState<T> extends State<OlAsync<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      final Widget child;
      if (snap.hasError) {
        final e = snap.error;
        child = OlErrorCard(
          message: e is AppError ? e.message : 'Data belum bisa dimuat.',
          refId: e is AppError ? e.refId : null,
          onRetry: _reload,
        );
      } else if (!snap.hasData) {
        child = const OlLoadingCard();
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, w)
                in widget
                    .builder(context, snap.data as T, _reload)
                    .indexed) ...[
              if (i > 0) const SizedBox(height: OlSpace.lg),
              w,
            ],
          ],
        );
      }
      return child;
    },
  );
}

class OlLoadingCard extends StatelessWidget {
  const OlLoadingCard({super.key});

  @override
  Widget build(BuildContext context) => const OlCard(
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
  );
}

class OlErrorCard extends StatelessWidget {
  const OlErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    this.refId,
  });

  final String message;
  final String? refId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.olText;
    return OlCard(
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: context.ol.muted),
          ),
          if (refId != null) ...[
            const SizedBox(height: 4),
            Text(
              'Kode: $refId',
              style: t.mono.copyWith(color: context.ol.faint),
            ),
          ],
          const SizedBox(height: OlSpace.md),
          OlButton(label: 'Coba lagi', expand: false, onPressed: onRetry),
        ],
      ),
    );
  }
}

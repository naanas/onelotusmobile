import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/pasien/pasien_app_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// Satu file rontgen di form booking pasien.
class RontgenItem {
  RontgenItem(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
  String? id;
  bool failed = false;
  String? error;
  bool get busy => id == null && !failed;
}

/// Daftar rontgen yang dipilih pasien. Dipegang halaman booking agar tidak hilang saat pindah langkah.
/// File langsung diunggah (dienkripsi server); dikaitkan ke booking setelah booking dibuat ([ids]).
class RontgenController extends ChangeNotifier {
  RontgenController(this._api);
  final PasienAppApi Function() _api;
  final items = <RontgenItem>[];

  static const max = 3;

  List<String> get ids => [for (final i in items) if (i.id != null) i.id!];
  bool get uploading => items.any((i) => i.busy);

  Future<void> add(Uint8List bytes, String mime) async {
    if (items.length >= max) return;
    final item = RontgenItem(bytes, mime);
    items.add(item);
    notifyListeners();
    await _upload(item);
  }

  Future<void> retry(RontgenItem item) => _upload(item);

  Future<void> _upload(RontgenItem item) async {
    item
      ..failed = false
      ..error = null;
    notifyListeners();
    try {
      item.id = await _api().uploadIntake(item.bytes, item.mime);
    } catch (e) {
      item
        ..failed = true
        ..error = 'Gagal diunggah. Ketuk untuk coba lagi.';
    }
    notifyListeners();
  }

  void remove(RontgenItem item) {
    items.remove(item);
    notifyListeners();
  }

  void clear() {
    items.clear();
    notifyListeners();
  }
}

/// Unggah foto rontgen (opsional) di langkah Keluhan: galeri atau kamera, maks. 3.
class RontgenPicker extends StatelessWidget {
  const RontgenPicker({super.key, required this.controller});
  final RontgenController controller;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source, maxWidth: 2400, maxHeight: 2400, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    final name = img.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    await controller.add(bytes, mime);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = context.ol;
      final t = context.olText;
      final items = controller.items;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Foto hasil rontgen (opsional)', style: t.fieldLabel),
          const SizedBox(height: OlSpace.sm),
          Wrap(
            spacing: OlSpace.sm,
            runSpacing: OlSpace.sm,
            children: [
              for (final i in items)
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: i.failed ? () => controller.retry(i) : null,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(i.bytes, fit: BoxFit.cover, gaplessPlayback: true),
                        ),
                      ),
                      if (i.busy || i.failed)
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: i.failed ? 0.55 : 0.35),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: i.failed
                                  ? const OlIcon(OlIcons.refresh, color: Colors.white)
                                  : const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                    ),
                            ),
                          ),
                        ),
                      if (i.id != null)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: c.ok, shape: BoxShape.circle),
                            child: const OlIcon(OlIcons.check, size: 12, color: Colors.white),
                          ),
                        ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Semantics(
                          button: true,
                          label: 'Hapus foto rontgen',
                          child: GestureDetector(
                            onTap: () => controller.remove(i),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const OlIcon(OlIcons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (items.length < RontgenController.max) ...[
                _AddTile(icon: OlIcons.upload, label: 'Galeri', onTap: () => _pick(context, ImageSource.gallery)),
                _AddTile(icon: OlIcons.camera, label: 'Kamera', onTap: () => _pick(context, ImageSource.camera)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            items.any((i) => i.failed)
                ? 'Ada foto yang gagal diunggah. Ketuk fotonya untuk coba lagi.'
                : 'Maks. 3 foto. Disimpan terenkripsi dan hanya bisa dibuka terapis One Lotus.',
            style: t.caption.copyWith(color: items.any((i) => i.failed) ? c.crit : c.muted),
          ),
        ],
      );
    },
  );
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});
  final OlIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ol;
    final t = context.olText;
    return Semantics(
      button: true,
      label: 'Tambah foto rontgen dari ${label.toLowerCase()}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.brand.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OlIcon(icon, color: c.brand),
              const SizedBox(height: 4),
              Text(label, style: t.caption.copyWith(color: c.brand, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

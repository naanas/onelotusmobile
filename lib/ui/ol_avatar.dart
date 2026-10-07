import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Avatar inisial (`.av`): gradien biru lembut, inisial `brandDeep`.
class OlAvatar extends StatelessWidget {
  const OlAvatar({super.key, required this.name, this.large = false});

  final String name;
  final bool large;

  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = large ? 60.0 : 42.0;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE3F2FC), Color(0xFFCBE6F7)],
          ),
        ),
        child: Text(
          initialsOf(name),
          style: context.olText.body.copyWith(
            fontSize: large ? 19 : 14,
            fontWeight: FontWeight.w800,
            color: context.ol.brandDeep,
          ),
        ),
      ),
    );
  }
}

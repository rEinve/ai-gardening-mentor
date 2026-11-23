import 'package:flutter/material.dart';

/// Official AI Gardening Mentor brand icon rendered from `assets/branding/logo_icon.png`.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 56,
    this.semanticLabel = 'AI Gardening Mentor logo',
  });

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Image.asset(
      'assets/branding/logo_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.eco, size: size, color: cs.primary),
    );
  }
}

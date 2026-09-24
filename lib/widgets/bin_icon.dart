import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/bin_scheme.dart';

class BinIcon extends StatelessWidget {
  final BinPresentation presentation;
  final Color color;
  final double size;
  final String? semanticLabel;

  const BinIcon({
    super.key,
    required this.presentation,
    required this.color,
    required this.size,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? presentation.label;
    final assetPath = presentation.assetPath;
    if (assetPath != null) {
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        semanticsLabel: label,
      );
    }

    final icon = presentation.icon;
    if (icon == null) return const SizedBox.shrink();
    return Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: label,
    );
  }
}

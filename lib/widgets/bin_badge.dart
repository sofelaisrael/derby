import 'package:flutter/material.dart';
import '../services/bin_scheme.dart';
import '../widgets/bin_icon.dart';
import '../widgets/bin_swatch.dart';
import '../theme/app_colors.dart';

/// A colour-coded bin "token" chip: solid bin colour with a white glyph.
/// Stands in for the literal illustrated wheelie bin in compact schedule and
/// guide rows so each bin reads instantly by colour + glyph, and stays crisp
/// at small sizes. Glyphs mirror the postcode hero badges.
class BinBadge extends StatelessWidget {
  final BinPresentation presentation;
  final double size;

  const BinBadge({super.key, required this.presentation, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        BinSwatch(p: presentation, size: size, radius: size * 0.28),
        BinIcon(
          presentation: presentation,
          color: binForeground(presentation.themed(context).bodyColor),
          size: size * 0.46,
          semanticLabel: presentation.label,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../services/bin_scheme.dart';
import '../theme/spacing.dart';

/// A small two-tone bin swatch: a coloured lid strip on top of a (usually
/// darker) body. For single-colour bins the lid and body are identical, so the
/// split is invisible and the swatch reads as a solid block.
class BinSwatch extends StatelessWidget {
  final BinPresentation p;
  final double size;
  final double? radius;

  const BinSwatch({super.key, required this.p, this.size = 30, this.radius});

  @override
  Widget build(BuildContext context) {
    final t = p.themed(context);
    final r = radius ?? AppSpacing.radiusSm;
    final lidHeight = size * 0.34;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            Container(
              width: size,
              height: lidHeight,
              color: t.lidColor,
            ),
            Container(
              width: size,
              height: size - lidHeight,
              color: t.bodyColor,
            ),
          ],
        ),
      ),
    );
  }
}

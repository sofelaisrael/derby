import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/spacing.dart';

/// Renders a bundled unDraw SVG illustration on a rounded white "plate" so
/// the light-navy/light-grey artwork stays legible in both light and dark
/// mode. The SVG keeps its own aspect ratio ([BoxFit.contain]).
///
/// When [progress] is provided the whole plate fades in and rises as part of
/// the step's staggered entrance (composed outside the plate).
class UndrawArt extends StatelessWidget {
  final String asset;
  final Animation<double>? progress;
  final BoxFit fit;

  const UndrawArt({
    super.key,
    required this.asset,
    this.progress,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final plate = Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SvgPicture.asset(asset, fit: fit),
    );

    final p = progress;
    if (p == null) return plate;

    return AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final v = p.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - v)),
            child: plate,
          ),
        );
      },
    );
  }
}
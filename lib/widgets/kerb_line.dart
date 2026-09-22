import 'package:flutter/material.dart';

/// A hand-drawn "kerb line" scene: the brand's four wheelie bins lined up
/// along a ground band, one highlighted as the bin going out this week.
///
/// Shared by onboarding step 0 (full-size art) and the postcode hero (~72px).
/// Flat fills + soft internal shading, zero outlines (a single 1px light rim
/// on the glass bin in dark mode is the only exception). Contact shadows and
/// the highlight glow are feathered ellipses — never a hardware drop shadow.
class KerbLine extends StatelessWidget {
  /// Bin hues, drawn back-to-front (last entry is the front-most bin).
  final List<Color> colors;

  /// Index into [colors] of the lifted, glowing bin. -1 disables.
  final int highlightedIndex;

  /// Optional entrance animation (0..1). When null the scene renders settled.
  final Animation<double>? progress;

  /// When false the painter skips the decorative floating dots.
  final bool showDots;

  final Size size;

  const KerbLine({
    super.key,
    required this.colors,
    this.highlightedIndex = -1,
    this.progress,
    this.showDots = true,
    this.size = const Size(300, 200),
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        painter: _KerbPainter(
          colors: colors,
          highlightedIndex: highlightedIndex,
          dark: dark,
          showDots: showDots,
          progress: progress,
        ),
      ),
    );
  }
}

class _KerbPainter extends CustomPainter {
  final List<Color> colors;
  final int highlightedIndex;
  final bool dark;
  final bool showDots;
  final Animation<double>? progress;

  _KerbPainter({
    required this.colors,
    required this.highlightedIndex,
    required this.dark,
    required this.showDots,
    required this.progress,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = progress?.value ?? 1.0;

    // Ground band — 90% width, rounded, sits at the base.
    final groundAlpha = _seg(p, 0.00, 0.20);
    final ground = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.05, h * 0.90, w * 0.90, h * 0.10),
      topLeft: Radius.circular(h * 0.05),
      topRight: Radius.circular(h * 0.05),
      bottomLeft: Radius.circular(h * 0.05),
      bottomRight: Radius.circular(h * 0.05),
    );
    canvas.drawRRect(
      ground,
      Paint()
        ..color = (dark ? const Color(0xFF34393A) : const Color(0xFFE2E8F0))
            .withValues(alpha: groundAlpha),
    );

    final gy = h * 0.90;

    // Glow behind the highlighted bin (drawn first so the bin covers it).
    if (highlightedIndex >= 0 && highlightedIndex < colors.length) {
      final glowEnt = _seg(p, 0.45, 0.75);
      if (glowEnt > 0) {
        final hue = colors[highlightedIndex];
        final cx = _centerX(highlightedIndex, w);
        final lift = _seg(p, 0.45, 0.65);
        final cy = gy - _boxHeight(highlightedIndex, w) * 0.55 -
            h * 0.03 * lift;
        _drawFeatheredEllipse(
          canvas,
          center: Offset(cx, cy),
          rx: _boxWidth(highlightedIndex, w) * 0.80,
          ry: _boxHeight(highlightedIndex, w) * 0.58,
          color: hue.withValues(alpha: 0.30 * glowEnt),
        );
      }
    }

    // Bins back → front.
    for (var i = 0; i < colors.length; i++) {
      final entrance = _seg(p, 0.08 + i * 0.06, 0.30 + i * 0.06);
      if (entrance <= 0) continue;

      // Contact shadow per bin.
      final shadowW = _boxWidth(i, w) * 0.9;
      _drawFeatheredEllipse(
        canvas,
        center: Offset(_centerX(i, w), gy + h * 0.015),
        rx: shadowW * 0.5,
        ry: shadowW * 0.10,
        color: Colors.black.withValues(alpha: (dark ? 0.28 : 0.10) * entrance),
      );

      final highlighted = i == highlightedIndex;
      final globalScale =
          (highlighted ? (1.0 + 0.08 * _seg(p, 0.45, 0.65)) : 1.0);
      final box = _binBox(i, w, h, entrance, globalScale);

      final hue = colors[i];
      final isGlass = dark && _isGlassHue(hue);
      _paintBin(canvas, box, hue, isGlass);
    }

    // Decorative floating dots (hidden when disabled).
    if (showDots) {
      final dots = [
        (Offset(w * 0.12, h * 0.24), colors[2 % colors.length], 8.0),
        (Offset(w * 0.88, h * 0.18), colors[1 % colors.length], 6.0),
        (Offset(w * 0.80, h * 0.34), colors[0 % colors.length], 7.0),
      ];
      for (final d in dots) {
        _drawFeatheredEllipse(
          canvas,
          center: d.$1,
          rx: d.$3 * 0.5,
          ry: d.$3 * 0.5,
          color: d.$2.withValues(alpha: 0.18),
        );
      }
    }
  }

  double _centerX(int i, double w) => w * (0.26 + i * 0.16);

  double _baseScale(int i) => 0.70 + i * 0.10;

  double _boxWidth(int i, double w) =>
      w * 0.21 * _baseScale(i);

  double _boxHeight(int i, double w) => _boxWidth(i, w) * 1.45;

  Rect _binBox(int i, double w, double h, double entrance, double extra) {
    final bw = _boxWidth(i, w) * entrance * extra;
    final bh = bw * 1.45;
    final cx = _centerX(i, w);
    // Drop from above during entrance (easeOutCubic already baked into [entrance]).
    final drop = bh * 0.35 * (1 - entrance);
    final top = (h * 0.90 - bh) + drop;
    return Rect.fromLTWH(cx - bw / 2, top, bw, bh);
  }

  static bool _isGlassHue(Color hue) =>
      hue == const Color(0xFF6B7A86) || hue == const Color(0xFF4A5560);

  void _drawFeatheredEllipse(
    Canvas canvas, {
    required Offset center,
    required double rx,
    required double ry,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, ry / rx);
    canvas.translate(-center.dx, -center.dy);
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: rx * 2, height: rx * 2),
      Radius.circular(rx),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  double _seg(double p, double a, double b) {
    if (p <= a) return 0;
    if (p >= b) return 1;
    return Curves.easeOutCubic.transform((p - a) / (b - a));
  }

  void _paintBin(Canvas canvas, Rect box, Color color, bool glassRim) {
    final w = box.width;
    final h = box.height;
    final dark = Color.lerp(color, const Color(0xFF000000), 0.16)!;
    final darker = Color.lerp(color, const Color(0xFF000000), 0.32)!;
    final light = Color.lerp(color, const Color(0xFFFFFFFF), 0.28)!;

    canvas.save();
    canvas.translate(box.left, box.top);

    // Body (slightly tapered can).
    final body = Path()
      ..moveTo(w * 0.20, h * 0.48)
      ..lineTo(w * 0.80, h * 0.48)
      ..quadraticBezierTo(w * 0.82, h * 0.60, w * 0.80, h * 0.80)
      ..lineTo(w * 0.64, h * 0.88)
      ..lineTo(w * 0.36, h * 0.88)
      ..lineTo(w * 0.20, h * 0.80)
      ..quadraticBezierTo(w * 0.18, h * 0.60, w * 0.20, h * 0.48)
      ..close();
    canvas.drawPath(body, Paint()..color = color);

    // False-side shade for volume.
    final bodyShade = Path()
      ..moveTo(w * 0.68, h * 0.50)
      ..lineTo(w * 0.80, h * 0.48)
      ..quadraticBezierTo(w * 0.82, h * 0.60, w * 0.80, h * 0.80)
      ..lineTo(w * 0.64, h * 0.88)
      ..lineTo(w * 0.60, h * 0.88)
      ..lineTo(w * 0.74, h * 0.80)
      ..quadraticBezierTo(w * 0.76, h * 0.60, w * 0.66, h * 0.50)
      ..close();
    canvas.drawPath(bodyShade, Paint()..color = dark.withValues(alpha: 0.55));

    // Rib band + sheen.
    final rib = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.21, h * 0.52, w * 0.795, h * 0.60),
      bottomLeft: Radius.circular(w * 0.02),
      bottomRight: Radius.circular(w * 0.02),
    );
    canvas.drawRRect(rib, Paint()..color = light.withValues(alpha: 0.5));

    final sheen = Path()
      ..moveTo(w * 0.30, h * 0.56)
      ..lineTo(w * 0.36, h * 0.56)
      ..lineTo(w * 0.34, h * 0.82)
      ..lineTo(w * 0.28, h * 0.82)
      ..close();
    canvas.drawPath(sheen, Paint()..color = Colors.white.withValues(alpha: 0.28));

    // Lid.
    final lid = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.14, h * 0.30, w * 0.86, h * 0.50),
      topLeft: Radius.circular(w * 0.14),
      topRight: Radius.circular(w * 0.14),
    );
    canvas.drawRRect(lid, Paint()..color = dark);

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.14, h * 0.30, w * 0.86, h * 0.36),
        topLeft: Radius.circular(w * 0.14),
        topRight: Radius.circular(w * 0.14),
      ),
      Paint()..color = _lighter(dark),
    );

    final handle = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.44, h * 0.22, w * 0.56, h * 0.32),
      topLeft: Radius.circular(w * 0.06),
      topRight: Radius.circular(w * 0.06),
    );
    canvas.drawRRect(handle, Paint()..color = _lighter(darker));

    // Wheels.
    final wheelPaint = Paint()..color = const Color(0xFF2A2F2B);
    canvas.drawCircle(Offset(w * 0.34, h * 0.86), w * 0.10, wheelPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.86), w * 0.10, wheelPaint);
    final hubPaint = Paint()..color = const Color(0xFF545C56);
    canvas.drawCircle(Offset(w * 0.34, h * 0.86), w * 0.035, hubPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.86), w * 0.035, hubPaint);

    // Glass-bin rim (light mode even with no outline): soft 1px light rim.
    if (glassRim) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(w * 0.20, h * 0.48, w * 0.80, h * 0.88),
          topLeft: Radius.circular(w * 0.02),
          topRight: Radius.circular(w * 0.02),
          bottomLeft: Radius.circular(w * 0.04),
          bottomRight: Radius.circular(w * 0.04),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF7C8C82).withValues(alpha: 0.40),
      );
    }

    canvas.restore();
  }

  Color _lighter(Color c) => Color.lerp(c, const Color(0xFFFFFFFF), 0.42)!;

  @override
  bool shouldRepaint(_KerbPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.highlightedIndex != highlightedIndex ||
      oldDelegate.dark != dark ||
      oldDelegate.showDots != showDots ||
      oldDelegate.progress != progress;
}
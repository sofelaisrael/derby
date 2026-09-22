import 'package:flutter/material.dart';

/// A hand-drawn illustrated wheelie bin (vector, no asset/image needed).
/// Used in the hero card and bin guide so bins read as real, recognisable
/// objects rather than generic Material icons.
class BinIllustration extends StatelessWidget {
  final Color color;
  final double size;

  const BinIllustration({super.key, required this.color, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BinPainter(color),
    );
  }
}

class _BinPainter extends CustomPainter {
  final Color color;

  const _BinPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dark = Color.lerp(color, const Color(0xFF000000), 0.16)!;
    final darker = Color.lerp(color, const Color(0xFF000000), 0.32)!;
    final light = Color.lerp(color, const Color(0xFFFFFFFF), 0.28)!;

    // ── Body (slightly tapered can) ────────────────
    final body = Path()
      ..moveTo(w * 0.20, h * 0.48)
      ..lineTo(w * 0.80, h * 0.48)
      ..quadraticBezierTo(w * 0.82, h * 0.60, w * 0.80, h * 0.80)
      ..lineTo(w * 0.64, h * 0.88)
      ..lineTo(w * 0.36, h * 0.88)
      ..lineTo(w * 0.20, h * 0.80)
      ..quadraticBezierTo(w * 0.18, h * 0.60, w * 0.20, h * 0.48)
      ..close();
    canvas.drawShadow(body, color.withValues(alpha: 0.5), h * 0.05, true);
    canvas.drawPath(body, Paint()..color = color);

    // False-side shadow for volume
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

    // ── Rib band + highlight sheen on the can ──────
    final rib = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.21, h * 0.52, w * 0.795, h * 0.60),
      bottomLeft: Radius.circular(w * 0.02),
      bottomRight: Radius.circular(w * 0.02),
    );
    canvas.drawRRect(rib, Paint()..color = light.withValues(alpha: 0.5));

    // soft vertical sheen, left
    final sheen = Path()
      ..moveTo(w * 0.30, h * 0.56)
      ..lineTo(w * 0.36, h * 0.56)
      ..lineTo(w * 0.34, h * 0.82)
      ..lineTo(w * 0.28, h * 0.82)
      ..close();
    canvas.drawPath(sheen, Paint()..color = Colors.white.withValues(alpha: 0.28));

    // ── Lid ────────────────────────────────────────
    final lid = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.14, h * 0.30, w * 0.86, h * 0.50),
      topLeft: Radius.circular(w * 0.14),
      topRight: Radius.circular(w * 0.14),
    );
    canvas.drawRRect(lid, Paint()..color = dark);

    // lid underside (foreshadow before wheels) 
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.14, h * 0.30, w * 0.86, h * 0.36),
        topLeft: Radius.circular(w * 0.14),
        topRight: Radius.circular(w * 0.14),
      ),
      Paint()..color = lighter(dark),
    );

    // handle on the lid
    final handle = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.44, h * 0.22, w * 0.56, h * 0.32),
      topLeft: Radius.circular(w * 0.06),
      topRight: Radius.circular(w * 0.06),
    );
    canvas.drawRRect(handle, Paint()..color = lighter(darker));

    // ── Wheels ─────────────────────────────────────
    final wheelPaint = Paint()
      ..color = const Color(0xFF2A2F2B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.34, h * 0.86), w * 0.10, wheelPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.86), w * 0.10, wheelPaint);
    final hubPaint = Paint()..color = const Color(0xFF545C56);
    canvas.drawCircle(Offset(w * 0.34, h * 0.86), w * 0.035, hubPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.86), w * 0.035, hubPaint);
  }

  Color lighter(Color c) => Color.lerp(c, const Color(0xFFFFFFFF), 0.42)!;

  @override
  bool shouldRepaint(_BinPainter oldDelegate) => oldDelegate.color != color;
}
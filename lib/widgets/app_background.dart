import 'package:flutter/material.dart';

class ScreenBackground extends StatelessWidget {
  final Widget child;

  const ScreenBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF141513), Color(0xFF0D0E0C)]
              : const [Color(0xFFEFEAE0), Color(0xFFF6F3EC)],
        ),
      ),
      child: child,
    );
  }
}
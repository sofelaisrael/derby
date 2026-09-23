import 'package:flutter/material.dart';

LinearGradient bandedGradient(
  List<Color> colors, {
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) {
  final n = colors.length;
  final bandColors = <Color>[];
  final stops = <double>[];
  for (var i = 0; i < n; i++) {
    bandColors.add(colors[i]);
    bandColors.add(colors[i]);
    stops.add(i / n);
    stops.add((i + 1) / n);
  }
  return LinearGradient(
    begin: begin,
    end: end,
    colors: bandColors,
    stops: stops,
  );
}

List<Color> binTones(Color base) {
  final dark = Color.lerp(base, Colors.black, 0.35)!;
  final light = Color.lerp(base, Colors.white, 0.45)!;
  return [dark, base, light];
}

LinearGradient binBandedGradient(
  Color base, {
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) =>
    bandedGradient(binTones(base), begin: begin, end: end);

LinearGradient forestBandedGradient({
  bool dark = false,
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) =>
    bandedGradient(
      dark
          ? const [Color(0xFF0D0E0C), Color(0xFF1F3D2B), Color(0xFF2F5D43)]
          : const [Color(0xFF1F3D2B), Color(0xFF2F5D43), Color(0xFF7C8B6F)],
      begin: begin,
      end: end,
    );

LinearGradient multiBinBandedGradient(
  List<Color> bases, {
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) {
  final tones = <Color>[];
  for (final base in bases) {
    tones.addAll(binTones(base));
  }
  return bandedGradient(tones, begin: begin, end: end);
}
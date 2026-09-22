import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const display = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -1.5,
  );

  static const h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const h3 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}

class AppText {
  AppText._();

  static const masthead = TextStyle(
    fontSize: 30,
    height: 1.1,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const h1 = TextStyle(
    fontSize: 26,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
  );

  static const h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.5,
  );

  static const bodyWhite = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: Color(0xB3FFFFFF),
  );

  static const meta = TextStyle(
    fontSize: 12,
  );

  static const metaBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const buttonWhite = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}
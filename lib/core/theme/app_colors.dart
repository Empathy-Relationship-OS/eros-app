import 'package:flutter/material.dart';

/// The Muse palette ("Golden Hour"): coral on warm cream, with warm ink instead of black.
///
/// Rules that keep it readable:
/// - Text on a coral fill is [textOnPrimary] (ink, 6.4:1), never white (2.6:1).
/// - Coral ([primary]) is for fills. For coral-coloured text, links, icons and the selected state
///   on a light surface use [primaryDeep] (4.9:1 on [background]).
/// - Quiet fills (secondary buttons, chips, callouts) are [primaryTint].
class AppColors {
  AppColors._();

  // Brand
  static const Color primaryOrange = Color(0xFFFF7A52); // Coral: fills only
  static const Color primaryOrangeLight = Color(0xFFFFBCA3); // Light coral
  static const Color primaryOrangeDark = Color(0xFFC2410C); // Deep coral: text, links, icons

  // Convenience getter for primary color
  static const Color primary = primaryOrange;

  /// Coral that is readable as text or an icon on a light surface.
  static const Color primaryDeep = primaryOrangeDark;

  /// The quiet coral fill behind secondary buttons, chips and callouts.
  static const Color primaryTint = Color(0xFFFFE6DA);

  // Secondary Colors
  static const Color secondaryOrange = Color(0xFFFFC4A6); // Peach, mostly used at low opacity
  static const Color accentOrange = primaryOrangeDark;

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color ink = Color(0xFF2B1B14); // Warm near-black
  static const Color background = Color(0xFFFFF6F0); // Warm cream
  static const Color cardBackground = Color(0xFFFFFFFF); // Cards sit on the cream
  static const Color surfaceMuted = Color(0xFFFBEDE5); // A step darker than the background

  // Text Colors
  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF7A655B);
  static const Color textTertiary = Color(0xFF8E7B71); // Hints and placeholders only
  static const Color textOnPrimary = ink;

  // State Colors (each takes white text at 4.5:1 or better)
  static const Color success = Color(0xFF2E7D57);
  static const Color error = Color(0xFFC5362B);
  static const Color warning = Color(0xFFA35C00);
  static const Color info = Color(0xFF2F6FA3);

  // UI Element Colors
  static const Color divider = Color(0xFFF1DFD5);
  static const Color border = Color(0xFFD9C3B7);
  static const Color disabled = Color(0xFFF3E6DE);
  static const Color disabledText = Color(0xFFB9A79D);

  // Selection Colors
  static const Color selected = primaryTint;
  static const Color unselected = Color(0xFFFFFFFF);

  // Shadow
  static const Color shadow = Color(0x142B1B14); // 8% ink
}

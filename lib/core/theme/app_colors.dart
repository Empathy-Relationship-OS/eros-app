import 'package:flutter/material.dart';

/// App color palette based on Muse brand identity
/// Warm orange gradient with white and black accents
class AppColors {
  AppColors._();

  // Primary Colors - Warm Orange Gradient
  static const Color primaryOrange = Color(0xFFFF8A65); // Coral orange
  static const Color primaryOrangeLight = Color(0xFFFFAB91); // Light coral
  static const Color primaryOrangeDark = Color(0xFFFF6E40); // Deep coral

  // Convenience getter for primary color
  static const Color primary = primaryOrange;

  // Secondary Colors
  static const Color secondaryOrange = Color(0xFFFFCC80); // Peach
  static const Color accentOrange = Color(0xFFFF7043); // Vibrant orange

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color background = Color(0xFFFFF4EE); // Subtle warm orange background
  static const Color cardBackground = Color(0xFFFFFFFF); // Pure white for cards to stand out

  // Text Colors
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // State Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF29B6F6);

  // UI Element Colors
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFBDBDBD);
  static const Color disabled = Color(0xFFE0E0E0);
  static const Color disabledText = Color(0xFFBDBDBD);

  // Selection Colors
  static const Color selected = Color(0xFFE0E0E0); // Grey for selected items
  static const Color unselected = Color(0xFFFFFFFF);

  // Shadow
  static const Color shadow = Color(0x1A000000); // 10% black
}

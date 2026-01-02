import 'package:flutter/material.dart';

/// Application color scheme for VibeMobile Desktop.
/// Based on merged design scheme 3 - Step-by-step guided flow.
class AppColors {
  AppColors._();

  // Primary gradient colors (purple theme)
  static const Color gradientStart = Color(0xFF667eea);
  static const Color gradientEnd = Color(0xFF764ba2);

  // Background colors
  static const Color bgPrimary = Color(0xFFF5F5F7);
  static const Color bgSidebar = Color(0xFFFFFFFF);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgCardHover = Color(0xFFFAFAFA);

  // Text colors
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF86868B);

  // Accent colors
  static const Color accent = Color(0xFF007AFF);
  static const Color accentLight = Color(0xFFE5F1FF);

  // Status colors
  static const Color success = Color(0xFF34C759);
  static const Color successLight = Color(0xFFE8F9ED);
  static const Color warning = Color(0xFFFF9500);
  static const Color warningLight = Color(0xFFFFF7ED);
  static const Color danger = Color(0xFFFF3B30);
  static const Color dangerLight = Color(0xFFFEF2F2);

  // Border and shadow
  static const Color border = Color(0xFFE5E5E7);

  // Gradient definition
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Box shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> cardShadowHover = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadowLarge = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  // Border radius constants
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // Sidebar width
  static const double sidebarWidth = 240.0;
}

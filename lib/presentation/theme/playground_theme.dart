import 'package:flutter/material.dart';

/// Theme constants for the Developer Playground UI
class PlaygroundTheme {
  PlaygroundTheme._();

  // ============================================
  // Colors
  // ============================================

  /// Background colors
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2A2A2A);
  static const Color border = Color(0xFF333333);

  /// Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF666666);

  /// Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFEB3B);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);

  /// Accent colors
  static const Color accent = Color(0xFF2196F3);
  static const Color accentLight = Color(0xFF64B5F6);

  // ============================================
  // Performance Metric Colors
  // ============================================

  /// Get color for FPS value
  static Color fpsColor(double fps) {
    if (fps >= 25) return success;
    if (fps >= 15) return warning;
    return error;
  }

  /// Get color for latency value (ms)
  static Color latencyColor(double latencyMs) {
    if (latencyMs < 50) return success;
    if (latencyMs < 100) return warning;
    if (latencyMs < 150) return warningOrange;
    return error;
  }

  /// Get color for confidence value (0-1)
  static Color confidenceColor(double confidence) {
    if (confidence > 0.8) return success;
    if (confidence > 0.5) return warning;
    return error;
  }

  // ============================================
  // Spacing
  // ============================================

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;

  // ============================================
  // Panel Dimensions
  // ============================================

  static const double configPanelWidth = 220.0;
  static const double dataPanelWidth = 260.0;
  static const double collapsedPanelWidth = 36.0;
  static const double metricsBarHeight = 56.0;
  static const double bottomControlsHeight = 80.0;

  // ============================================
  // Border Radius
  // ============================================

  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusCircle = 99.0;

  // ============================================
  // Animation Durations
  // ============================================

  static const Duration panelAnimation = Duration(milliseconds: 200);
  static const Duration fadeAnimation = Duration(milliseconds: 150);

  // ============================================
  // Text Styles
  // ============================================

  static const TextStyle headingStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 0.3,
  );

  static const TextStyle valueStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFamily: 'monospace',
  );

  static const TextStyle valueSmallStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    fontFamily: 'monospace',
  );

  static const TextStyle badgeStyle = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  // ============================================
  // Decorations
  // ============================================

  static BoxDecoration get panelDecoration => BoxDecoration(
        color: surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: border, width: 1),
      );

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(radiusSm),
      );

  static BoxDecoration get metricsBarDecoration => BoxDecoration(
        color: surface.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: border, width: 1)),
      );

  // ============================================
  // Button Styles
  // ============================================

  static ButtonStyle presetButtonStyle({bool isSelected = false}) {
    return ElevatedButton.styleFrom(
      backgroundColor: isSelected ? accent : surfaceLight,
      foregroundColor: isSelected ? textPrimary : textSecondary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: Size.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        side: BorderSide(
          color: isSelected ? accent : border,
          width: 1,
        ),
      ),
    );
  }

  static ButtonStyle iconButtonStyle({Color? color}) {
    return IconButton.styleFrom(
      backgroundColor: color ?? surfaceLight,
      foregroundColor: textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCircle),
      ),
    );
  }
}

/// Extension for easy theme color access
extension PlaygroundColors on BuildContext {
  Color get pgBackground => PlaygroundTheme.background;
  Color get pgSurface => PlaygroundTheme.surface;
  Color get pgBorder => PlaygroundTheme.border;
  Color get pgTextPrimary => PlaygroundTheme.textPrimary;
  Color get pgTextSecondary => PlaygroundTheme.textSecondary;
  Color get pgTextMuted => PlaygroundTheme.textMuted;
  Color get pgSuccess => PlaygroundTheme.success;
  Color get pgWarning => PlaygroundTheme.warning;
  Color get pgError => PlaygroundTheme.error;
  Color get pgAccent => PlaygroundTheme.accent;
}

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════
//  ScanGo Design System — Patient App Color Tokens
//  Single source of truth for both Light and Dark themes.
//  Never use hardcoded hex values in screens — always use context.colors
// ══════════════════════════════════════════════════════════════════

/// A typed data class holding all color tokens for one theme.
class AppColorTokens {
  // ─── Brand ─────────────────────────────────────────────────────
  final Color primary;         // Main brand teal
  final Color primaryDark;     // Darker teal for hover/pressed
  final Color primaryDeep;     // Deepest teal for headers
  final Color primaryLight;    // 10% teal tint for icon backgrounds

  // ─── Accent ────────────────────────────────────────────────────
  final Color accent;          // Amber — CTAs like "احجز الآن"
  final Color accentLight;     // 12% amber tint

  // ─── Backgrounds ───────────────────────────────────────────────
  final Color background;      // App scaffold background
  final Color backgroundWarm;  // Slightly warmer bg for sections
  final Color surface;         // Cards, bottom nav, modals
  final Color surfaceVariant;  // Input fill, chips
  final Color surfaceElevated; // Elevated surfaces, dropdowns

  // ─── Text ──────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnPrimary;   // Text on teal buttons

  // ─── Borders ───────────────────────────────────────────────────
  final Color border;
  final Color borderLight;

  // ─── Semantic ──────────────────────────────────────────────────
  final Color error;
  final Color errorBg;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color info;
  final Color infoBg;

  // ─── Skeleton shimmer ──────────────────────────────────────────
  final Color skeletonBase;
  final Color skeletonHighlight;

  // ─── Hero header ───────────────────────────────────────────────
  final Color headerBg;
  final Color headerBgEnd;

  const AppColorTokens({
    required this.primary,
    required this.primaryDark,
    required this.primaryDeep,
    required this.primaryLight,
    required this.accent,
    required this.accentLight,
    required this.background,
    required this.backgroundWarm,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnPrimary,
    required this.border,
    required this.borderLight,
    required this.error,
    required this.errorBg,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.info,
    required this.infoBg,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.headerBg,
    required this.headerBgEnd,
  });

  // ─── Card Shadow ─────────────────────────────────────────────
  List<BoxShadow> get cardShadow => [
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  List<BoxShadow> get primaryGlow => [
    BoxShadow(color: primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4)),
  ];
}

// ══════════════════════════════════════════════════════════════════
//  AppColors — Static instances for light and dark
// ══════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ─── Shared Status Colors (identical in both themes) ──────────
  // Per design system: status colors are non-negotiable and identical.
  static const Color statusPending     = Color(0xFFD97B0A);
  static const Color statusPendingBg   = Color(0xFFFEF3E2);
  static const Color statusPendingBgDk = Color(0x26D97B0A);

  static const Color statusAccepted     = Color(0xFF2B7EC2);
  static const Color statusAcceptedBg   = Color(0xFFE6F0FA);
  static const Color statusAcceptedBgDk = Color(0x262B7EC2);

  static const Color statusAssigned     = Color(0xFF2B7EC2);
  static const Color statusAssignedBg   = Color(0xFFE6F0FA);
  static const Color statusAssignedBgDk = Color(0x262B7EC2);

  static const Color statusOnWay     = Color(0xFFD97B0A);
  static const Color statusOnWayBg   = Color(0xFFFEF3E2);
  static const Color statusOnWayBgDk = Color(0x26D97B0A);

  static const Color statusArrived     = Color(0xFF1D9E75);
  static const Color statusArrivedBg   = Color(0xFFE8F5F0);
  static const Color statusArrivedBgDk = Color(0x261D9E75);

  static const Color statusInProgress     = Color(0xFF1D9E75);
  static const Color statusInProgressBg   = Color(0xFFE8F5F0);
  static const Color statusInProgressBgDk = Color(0x261D9E75);

  static const Color statusCompleted     = Color(0xFF4D8C2C);
  static const Color statusCompletedBg   = Color(0xFFEFF6E8);
  static const Color statusCompletedBgDk = Color(0x264D8C2C);

  static const Color statusReportReady     = Color(0xFF4D8C2C);
  static const Color statusReportReadyBg   = Color(0xFFEFF6E8);
  static const Color statusReportReadyBgDk = Color(0x264D8C2C);

  static const Color statusCancelled     = Color(0xFFD44245);
  static const Color statusCancelledBg   = Color(0xFFFCE8E8);
  static const Color statusCancelledBgDk = Color(0x26D44245);

  // ─── Light Theme Tokens ───────────────────────────────────────
  static const AppColorTokens light = AppColorTokens(
    // Brand
    primary:       Color(0xFF1D9E75),
    primaryDark:   Color(0xFF16755A),
    primaryDeep:   Color(0xFF085041),
    primaryLight:  Color(0x1A1D9E75),   // ~10% teal

    // Accent (amber for CTAs)
    accent:        Color(0xFFD97B0A),
    accentLight:   Color(0x1AD97B0A),

    // Backgrounds — warm cream whites
    background:     Color(0xFFFAFAF7),  // warm white scaffold
    backgroundWarm: Color(0xFFF1EFE8),  // secondary warm bg
    surface:        Color(0xFFFFFFFF),  // pure white cards
    surfaceVariant: Color(0xFFF5F5F2),  // input fill
    surfaceElevated:Color(0xFFF0EEE7),  // elevated (dropdowns)

    // Text
    textPrimary:   Color(0xFF1A1A1A),
    textSecondary: Color(0xFF5A5A5A),
    textMuted:     Color(0xFF9CA3AF),
    textOnPrimary: Color(0xFFFFFFFF),

    // Borders
    border:        Color(0xFFE5E5E0),
    borderLight:   Color(0xFFEEEEE8),

    // Semantic
    error:      Color(0xFFD44245),
    errorBg:    Color(0xFFFCE8E8),
    success:    Color(0xFF4D8C2C),
    successBg:  Color(0xFFEFF6E8),
    warning:    Color(0xFFD97B0A),
    warningBg:  Color(0xFFFEF3E2),
    info:       Color(0xFF2B7EC2),
    infoBg:     Color(0xFFE6F0FA),

    // Skeleton shimmer
    skeletonBase:      Color(0xFFE8E8E4),
    skeletonHighlight: Color(0xFFF5F5F2),

    // Hero header (clean teal-to-white)
    headerBg:    Color(0xFF085041),
    headerBgEnd: Color(0xFF1D9E75),
  );

  // ─── Dark Theme Tokens ────────────────────────────────────────
  static const AppColorTokens dark = AppColorTokens(
    // Brand (same teal — bright on dark)
    primary:       Color(0xFF1D9E75),
    primaryDark:   Color(0xFF16755A),
    primaryDeep:   Color(0xFF085041),
    primaryLight:  Color(0x261D9E75),   // ~15% teal

    // Accent
    accent:        Color(0xFFD97B0A),
    accentLight:   Color(0x26D97B0A),

    // Backgrounds — deep navy
    background:     Color(0xFF0F1729),  // app scaffold
    backgroundWarm: Color(0xFF0A0F1E),  // deeper navy
    surface:        Color(0xFF1A2332),  // cards
    surfaceVariant: Color(0xFF243044),  // input fill
    surfaceElevated:Color(0xFF2C3A52),  // elevated (dropdowns)

    // Text
    textPrimary:   Color(0xFFF0F0F0),
    textSecondary: Color(0xFF94A3B8),
    textMuted:     Color(0xFF64748B),
    textOnPrimary: Color(0xFFFFFFFF),

    // Borders
    border:        Color(0x1AFFFFFF),   // rgba(255,255,255,0.10)
    borderLight:   Color(0x0FFFFFFF),   // rgba(255,255,255,0.06)

    // Semantic
    error:      Color(0xFFD44245),
    errorBg:    Color(0x26D44245),
    success:    Color(0xFF4D8C2C),
    successBg:  Color(0x264D8C2C),
    warning:    Color(0xFFD97B0A),
    warningBg:  Color(0x26D97B0A),
    info:       Color(0xFF2B7EC2),
    infoBg:     Color(0x262B7EC2),

    // Skeleton shimmer
    skeletonBase:      Color(0xFF1A2332),
    skeletonHighlight: Color(0xFF243044),

    // Hero header (dark navy)
    headerBg:    Color(0xFF0A0F1E),
    headerBgEnd: Color(0xFF0F1729),
  );

  // ─── Status Color Helpers ─────────────────────────────────────
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':       return statusPending;
      case 'accepted':      return statusAccepted;
      case 'assigned':      return statusAssigned;
      case 'on_way':        return statusOnWay;
      case 'arrived':       return statusArrived;
      case 'in_progress':   return statusInProgress;
      case 'completed':     return statusCompleted;
      case 'report_ready':  return statusReportReady;
      case 'cancelled':     return statusCancelled;
      default:              return const Color(0xFF9CA3AF);
    }
  }

  static Color getStatusBgColor(String status, {bool dark = false}) {
    switch (status) {
      case 'pending':       return dark ? statusPendingBgDk     : statusPendingBg;
      case 'accepted':      return dark ? statusAcceptedBgDk    : statusAcceptedBg;
      case 'assigned':      return dark ? statusAssignedBgDk    : statusAssignedBg;
      case 'on_way':        return dark ? statusOnWayBgDk       : statusOnWayBg;
      case 'arrived':       return dark ? statusArrivedBgDk     : statusArrivedBg;
      case 'in_progress':   return dark ? statusInProgressBgDk  : statusInProgressBg;
      case 'completed':     return dark ? statusCompletedBgDk   : statusCompletedBg;
      case 'report_ready':  return dark ? statusReportReadyBgDk : statusReportReadyBg;
      case 'cancelled':     return dark ? statusCancelledBgDk   : statusCancelledBg;
      default:              return dark ? const Color(0xFF1A2332) : const Color(0xFFF5F5F2);
    }
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending':       return 'قيد المراجعة';
      case 'accepted':      return 'تم القبول';
      case 'assigned':      return 'تم التعيين';
      case 'on_way':        return 'في الطريق';
      case 'arrived':       return 'وصل الفني';
      case 'in_progress':   return 'جاري الفحص';
      case 'completed':     return 'اكتمل الفحص';
      case 'report_ready':  return 'التقرير جاهز';
      case 'cancelled':     return 'ملغي';
      default:              return status;
    }
  }
}

// ══════════════════════════════════════════════════════════════════
//  BuildContext Extension — the main way screens get colors
//  Usage: context.colors.primary, context.colors.surface, etc.
// ══════════════════════════════════════════════════════════════════
extension AppColorsExtension on BuildContext {
  /// Returns the correct color token set for the current theme.
  AppColorTokens get colors {
    final brightness = Theme.of(this).brightness;
    return brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  }

  /// Convenience: true when dark mode is active.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

import 'package:flutter/material.dart';

/// ScanGo Design System — Patient App Colors (Light Theme)
/// Single source of truth. Never use hardcoded hex in screens.
class AppColors {
  AppColors._();

  // ─── Brand Colors ─────────────────────────────────────────
  static const Color primary = Color(0xFF1D9E75);
  static const Color primaryDark = Color(0xFF16755A);
  static const Color primaryDeep = Color(0xFF085041);
  static const Color primaryLight = Color(0xFFE8F5F0);

  // ─── Surface Colors (Light Theme) ─────────────────────────
  static const Color background = Color(0xFFFAFAF7);
  static const Color warmBackground = Color(0xFFF1EFE8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F2);

  // ─── Text Colors ──────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF5A5A5A);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── Border Colors ────────────────────────────────────────
  static const Color border = Color(0xFFE5E5E0);
  static const Color borderLight = Color(0xFFF0F0EC);

  // ─── Status Colors (UNIFIED across all apps) ──────────────
  static const Color statusPending = Color(0xFFD97B0A);
  static const Color statusPendingBg = Color(0xFFFEF3E2);

  static const Color statusAccepted = Color(0xFF2B7EC2);
  static const Color statusAcceptedBg = Color(0xFFE6F0FA);

  static const Color statusAssigned = Color(0xFF2B7EC2);
  static const Color statusAssignedBg = Color(0xFFE6F0FA);

  static const Color statusOnWay = Color(0xFFD97B0A);
  static const Color statusOnWayBg = Color(0xFFFEF3E2);

  static const Color statusArrived = Color(0xFF1D9E75);
  static const Color statusArrivedBg = Color(0xFFE8F5F0);

  static const Color statusInProgress = Color(0xFF1D9E75);
  static const Color statusInProgressBg = Color(0xFFE8F5F0);

  static const Color statusCompleted = Color(0xFF4D8C2C);
  static const Color statusCompletedBg = Color(0xFFEFF6E8);

  static const Color statusReportReady = Color(0xFF4D8C2C);
  static const Color statusReportReadyBg = Color(0xFFEFF6E8);

  static const Color statusCancelled = Color(0xFFD44245);
  static const Color statusCancelledBg = Color(0xFFFCE8E8);

  // ─── Semantic Colors ──────────────────────────────────────
  static const Color error = Color(0xFFD44245);
  static const Color errorBg = Color(0xFFFCE8E8);
  static const Color success = Color(0xFF4D8C2C);
  static const Color successBg = Color(0xFFEFF6E8);
  static const Color warning = Color(0xFFD97B0A);
  static const Color warningBg = Color(0xFFFEF3E2);
  static const Color info = Color(0xFF2B7EC2);
  static const Color infoBg = Color(0xFFE6F0FA);

  // ─── Card Shadow ──────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  // ─── Status Helpers ───────────────────────────────────────
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return statusPending;
      case 'accepted':
        return statusAccepted;
      case 'assigned':
        return statusAssigned;
      case 'on_way':
        return statusOnWay;
      case 'arrived':
        return statusArrived;
      case 'in_progress':
        return statusInProgress;
      case 'completed':
        return statusCompleted;
      case 'report_ready':
        return statusReportReady;
      case 'cancelled':
        return statusCancelled;
      default:
        return textMuted;
    }
  }

  static Color getStatusBgColor(String status) {
    switch (status) {
      case 'pending':
        return statusPendingBg;
      case 'accepted':
        return statusAcceptedBg;
      case 'assigned':
        return statusAssignedBg;
      case 'on_way':
        return statusOnWayBg;
      case 'arrived':
        return statusArrivedBg;
      case 'in_progress':
        return statusInProgressBg;
      case 'completed':
        return statusCompletedBg;
      case 'report_ready':
        return statusReportReadyBg;
      case 'cancelled':
        return statusCancelledBg;
      default:
        return surfaceVariant;
    }
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'accepted':
        return 'تم القبول';
      case 'assigned':
        return 'تم التعيين';
      case 'on_way':
        return 'في الطريق';
      case 'arrived':
        return 'وصل الفني';
      case 'in_progress':
        return 'جاري الفحص';
      case 'completed':
        return 'اكتمل الفحص';
      case 'report_ready':
        return 'التقرير جاهز';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }
}

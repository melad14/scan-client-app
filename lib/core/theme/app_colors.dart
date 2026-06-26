import 'package:flutter/material.dart';

/// ScanGo Design System — Patient App Colors (Dark Modern Theme)
/// Single source of truth. Never use hardcoded hex in screens.
class AppColors {
  AppColors._();

  // ─── Brand Gradient Colors ─────────────────────────────────
  static const Color primary = Color(0xFF6C63FF);         // نيون بنفسجي
  static const Color primaryDark = Color(0xFF5A52E0);
  static const Color primaryDeep = Color(0xFF4840C8);
  static const Color primaryLight = Color(0x266C63FF);    // 15% opacity

  static const Color accent = Color(0xFF00D4AA);           // فيروزي نيون
  static const Color accentDark = Color(0xFF00B891);
  static const Color accentLight = Color(0x2600D4AA);     // 15% opacity

  // ─── Gradient Definitions ─────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1A1040), Color(0xFF0D2B3E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1E32), Color(0xFF252540)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Background Colors ────────────────────────────────────
  static const Color background = Color(0xFF0F0F1A);       // داكن جداً
  static const Color surface = Color(0xFF1A1A2E);          // كارد داكن
  static const Color surfaceVariant = Color(0xFF252540);   // variant
  static const Color surfaceElevated = Color(0xFF2A2A45);  // elevated

  // ─── Text Colors ─────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0CC);
  static const Color textMuted = Color(0xFF6B6B8A);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF0F0F1A);

  // ─── Border Colors ────────────────────────────────────────
  static const Color border = Color(0xFF2E2E4E);
  static const Color borderLight = Color(0xFF252545);
  static const Color borderGlow = Color(0x556C63FF);      // glow border

  // ─── Status Colors ────────────────────────────────────────
  static const Color statusPending = Color(0xFFFFB347);
  static const Color statusPendingBg = Color(0x33FFB347);

  static const Color statusAccepted = Color(0xFF64B5F6);
  static const Color statusAcceptedBg = Color(0x3364B5F6);

  static const Color statusAssigned = Color(0xFF64B5F6);
  static const Color statusAssignedBg = Color(0x3364B5F6);

  static const Color statusOnWay = Color(0xFFFFB347);
  static const Color statusOnWayBg = Color(0x33FFB347);

  static const Color statusArrived = Color(0xFF00D4AA);
  static const Color statusArrivedBg = Color(0x2600D4AA);

  static const Color statusInProgress = Color(0xFF00D4AA);
  static const Color statusInProgressBg = Color(0x2600D4AA);

  static const Color statusCompleted = Color(0xFF81C784);
  static const Color statusCompletedBg = Color(0x3381C784);

  static const Color statusReportReady = Color(0xFF81C784);
  static const Color statusReportReadyBg = Color(0x3381C784);

  static const Color statusCancelled = Color(0xFFEF5350);
  static const Color statusCancelledBg = Color(0x33EF5350);

  // ─── Semantic Colors ─────────────────────────────────────
  static const Color error = Color(0xFFEF5350);
  static const Color errorBg = Color(0x33EF5350);
  static const Color success = Color(0xFF81C784);
  static const Color successBg = Color(0x3381C784);
  static const Color warning = Color(0xFFFFB347);
  static const Color warningBg = Color(0x33FFB347);
  static const Color info = Color(0xFF64B5F6);
  static const Color infoBg = Color(0x3364B5F6);

  // ─── Glow Shadow ──────────────────────────────────────────
  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: primary.withOpacity(0.35),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get accentGlow => [
    BoxShadow(
      color: accent.withOpacity(0.3),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: primary.withOpacity(0.05),
      blurRadius: 24,
      offset: const Offset(0, 0),
    ),
  ];

  // ─── Status Helpers ───────────────────────────────────────
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending': return statusPending;
      case 'accepted': return statusAccepted;
      case 'assigned': return statusAssigned;
      case 'on_way': return statusOnWay;
      case 'arrived': return statusArrived;
      case 'in_progress': return statusInProgress;
      case 'completed': return statusCompleted;
      case 'report_ready': return statusReportReady;
      case 'cancelled': return statusCancelled;
      default: return textMuted;
    }
  }

  static Color getStatusBgColor(String status) {
    switch (status) {
      case 'pending': return statusPendingBg;
      case 'accepted': return statusAcceptedBg;
      case 'assigned': return statusAssignedBg;
      case 'on_way': return statusOnWayBg;
      case 'arrived': return statusArrivedBg;
      case 'in_progress': return statusInProgressBg;
      case 'completed': return statusCompletedBg;
      case 'report_ready': return statusReportReadyBg;
      case 'cancelled': return statusCancelledBg;
      default: return surfaceVariant;
    }
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'قيد المراجعة';
      case 'accepted': return 'تم القبول';
      case 'assigned': return 'تم التعيين';
      case 'on_way': return 'في الطريق';
      case 'arrived': return 'وصل الفني';
      case 'in_progress': return 'جاري الفحص';
      case 'completed': return 'اكتمل الفحص';
      case 'report_ready': return 'التقرير جاهز';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }
}

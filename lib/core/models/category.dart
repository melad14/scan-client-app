import 'package:flutter/material.dart';

class ServiceCategory {
  final String id;
  final String nameAr;
  final String nameEn;
  final String key;
  final String icon;
  final String iconBg;
  final String iconColor;
  final int sortOrder;
  final bool isActive;

  ServiceCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.sortOrder,
    required this.isActive,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['_id'] ?? '',
      nameAr: json['nameAr'] ?? '',
      nameEn: json['nameEn'] ?? '',
      key: json['key'] ?? '',
      icon: json['icon'] ?? 'category',
      iconBg: json['iconBg'] ?? '#E6F0FA',
      iconColor: json['iconColor'] ?? '#2B7EC2',
      sortOrder: json['sortOrder'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'key': key,
      'icon': icon,
      'iconBg': iconBg,
      'iconColor': iconColor,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  // Helper to map icon key to Material Icons
  IconData getIconData() {
    switch (icon) {
      case 'monitor_heart':
        return Icons.monitor_heart_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'show_chart':
        return Icons.show_chart_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'healing':
        return Icons.healing_rounded;
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // Helper to parse hexadecimal color string
  Color parseBgColor() {
    return _parseHexColor(iconBg, const Color(0xFFE6F0FA));
  }

  Color parseColor() {
    return _parseHexColor(iconColor, const Color(0xFF2B7EC2));
  }

  Color _parseHexColor(String hexStr, Color fallback) {
    try {
      final cleanHex = hexStr.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      } else if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}

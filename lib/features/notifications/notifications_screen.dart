import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/theme/app_colors.dart';
import 'package:patient_app/core/theme/ui_components.dart';
import 'package:dio/dio.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiClient();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.dio.get('/notifications');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _notifications = res.data['data'] ?? [];
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['message'] ?? 'فشل تحميل قائمة الإشعارات';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ غير متوقع';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String id, String? orderId) async {
    try {
      // Optimitic local UI update
      setState(() {
        for (var noti in _notifications) {
          if (noti['_id'] == id) {
            noti['isRead'] = true;
          }
        }
      });
      
      // Update on backend
      await _api.dio.put('/notifications/$id/read');
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }

    if (mounted && orderId != null && orderId.isNotEmpty) {
      context.push('/orders/$orderId');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      // Optimistic local UI update
      setState(() {
        for (var noti in _notifications) {
          noti['isRead'] = true;
        }
      });
      
      // Update on backend
      await _api.dio.put('/notifications/read-all');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديد جميع الإشعارات كمقروءة', style: TextStyle(fontFamily: 'Cairo')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to mark all as read: $e');
    }
  }

  String _formatRelativeTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) {
        return 'الآن';
      } else if (diff.inMinutes < 60) {
        return 'منذ ${diff.inMinutes} دقيقة';
      } else if (diff.inHours < 24) {
        return 'منذ ${diff.inHours} ساعة';
      } else if (diff.inDays < 7) {
        return 'منذ ${diff.inDays} يوم';
      } else {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return '';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'order_accepted':
        return Icons.check_circle_rounded;
      case 'tech_assigned':
        return Icons.assignment_ind_rounded;
      case 'tech_on_way':
        return Icons.local_shipping_rounded;
      case 'tech_arrived':
        return Icons.home_rounded;
      case 'report_ready':
        return Icons.description_rounded;
      case 'order_cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type, AppColorTokens c) {
    switch (type) {
      case 'order_accepted':
        return c.success;
      case 'tech_assigned':
        return c.info;
      case 'tech_on_way':
        return c.warning;
      case 'tech_arrived':
        return c.primary;
      case 'report_ready':
        return c.success;
      case 'order_cancelled':
        return c.error;
      default:
        return c.primary;
    }
  }

  Color _getNotificationBg(String type, AppColorTokens c) {
    switch (type) {
      case 'order_accepted':
        return c.successBg;
      case 'tech_assigned':
        return c.infoBg;
      case 'tech_on_way':
        return c.warningBg;
      case 'tech_arrived':
        return c.primaryLight;
      case 'report_ready':
        return c.successBg;
      case 'order_cancelled':
        return c.errorBg;
      default:
        return c.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasUnread = _notifications.any((noti) => noti['isRead'] == false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 0,
          title: Text(
            'الإشعارات',
            style: TextStyle(color: c.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: c.textPrimary, size: 20),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          actions: [
            if (hasUnread)
              TextButton.icon(
                onPressed: _markAllAsRead,
                icon: Icon(Icons.done_all_rounded, size: 16, color: c.primary),
                label: Text(
                  'قراءة الكل',
                  style: TextStyle(fontFamily: 'Cairo', color: c.primary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : _error != null
                ? ErrorStateWidget(
                    message: _error!,
                    onRetry: _fetchNotifications,
                  )
                : _notifications.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.notifications_off_rounded,
                        title: 'لا توجد إشعارات',
                        description: 'ستصلك هنا إشعارات فورية عند تحديث حالة زياراتك الطبية أو صدور تقاريرك.',
                        actionLabel: 'تحديث الصفحة',
                        onAction: _fetchNotifications,
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchNotifications,
                        color: c.primary,
                        backgroundColor: c.surface,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final noti = _notifications[index];
                            final id = noti['_id'];
                            final isRead = noti['isRead'] ?? false;
                            final title = noti['titleAr'] ?? '';
                            final body = noti['bodyAr'] ?? '';
                            final type = noti['type'] ?? 'generic';
                            final rawOrderId = noti['orderId'];
                            final String? orderId = (rawOrderId is Map)
                                ? rawOrderId['_id']?.toString()
                                : rawOrderId?.toString();
                            final timeStr = noti['createdAt'] != null ? _formatRelativeTime(noti['createdAt']) : '';

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isRead ? c.surface : c.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isRead ? c.borderLight : c.primary.withOpacity(0.2),
                                  width: isRead ? 1 : 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: () => _markAsRead(id, orderId?.toString()),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Notification Icon
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: _getNotificationBg(type, c),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getNotificationIcon(type),
                                            color: _getNotificationColor(type, c),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        // Title and Body
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: TextStyle(
                                                        fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                        fontSize: 14,
                                                        color: c.textPrimary,
                                                        fontFamily: 'Cairo',
                                                      ),
                                                    ),
                                                  ),
                                                  if (!isRead)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: c.accent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                body,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: c.textSecondary,
                                                  fontFamily: 'Cairo',
                                                  height: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: c.textMuted,
                                                      fontFamily: 'Cairo',
                                                    ),
                                                  ),
                                                  if (orderId != null)
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'تفاصيل الطلب',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: c.primary,
                                                            fontWeight: FontWeight.bold,
                                                            fontFamily: 'Cairo',
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: c.primary),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}

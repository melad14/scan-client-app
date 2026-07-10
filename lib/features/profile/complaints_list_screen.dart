import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/theme/app_colors.dart';
import 'package:patient_app/core/theme/ui_components.dart';
import 'package:dio/dio.dart';

class ComplaintsListScreen extends StatefulWidget {
  const ComplaintsListScreen({super.key});

  @override
  State<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends State<ComplaintsListScreen> {
  final _api = ApiClient();
  List<dynamic> _complaints = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.dio.get('/complaints/my');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _complaints = res.data['data'] ?? [];
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['message'] ?? 'فشل تحميل قائمة الشكاوى';
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

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة والتطوير';
      case 'forwarded':
        return 'تم التحويل للمركز للمتابعة';
      case 'resolved':
        return 'تم حل الشكوى بنجاح ✅';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status, AppColorTokens c) {
    switch (status) {
      case 'pending':
        return c.warning;
      case 'forwarded':
        return c.accent;
      case 'resolved':
        return c.success;
      default:
        return c.textSecondary;
    }
  }

  Color _getStatusBgColor(String status, AppColorTokens c) {
    switch (status) {
      case 'pending':
        return c.warningBg.withOpacity(0.08);
      case 'forwarded':
        return c.primaryLight;
      case 'resolved':
        return c.successBg;
      default:
        return c.borderLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/profile');
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 0,
          title: Text(
            'شكاواي واعتراضاتي',
            style: TextStyle(color: c.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: c.textPrimary, size: 20),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/profile');
              }
            },
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : _error != null
                ? ErrorStateWidget(
                    message: _error!,
                    onRetry: _fetchComplaints,
                  )
                : _complaints.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.mark_chat_read_rounded,
                        title: 'لا توجد شكاوى مسجلة',
                        description: 'ليست لديك أي شكاوى أو اعتراضات نشطة في الوقت الحالي.',
                        actionLabel: 'تحديث الصفحة',
                        onAction: _fetchComplaints,
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchComplaints,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _complaints.length,
                          itemBuilder: (context, index) {
                            final comp = _complaints[index];
                            final status = comp['status'] ?? 'pending';
                            final order = comp['orderId'];
                            final dateStr = comp['createdAt'] != null
                                ? DateTime.parse(comp['createdAt']).toLocal().toString().substring(0, 16)
                                : '-';

                            return Card(
                              color: c.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: c.borderLight),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          order != null ? 'طلب رقم: ${order['orderNumber']}' : 'طلب غير معروف',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.textPrimary, fontFamily: 'Cairo'),
                                        ),
                                        Text(
                                          dateStr,
                                          style: TextStyle(fontSize: 11, color: c.textMuted, fontFamily: 'Inter'),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Text(
                                      comp['text'] ?? '',
                                      style: TextStyle(fontSize: 13, color: c.textPrimary, fontFamily: 'Cairo', height: 1.5),
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _getStatusBgColor(status, c),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getStatusLabel(status),
                                        style: TextStyle(
                                          color: _getStatusColor(status, c),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          fontFamily: 'Cairo',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
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

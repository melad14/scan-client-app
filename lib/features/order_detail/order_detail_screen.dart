import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/order.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/theme/app_colors.dart';
import 'package:dio/dio.dart';
import 'dart:async';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final bool fromWizard;
  const OrderDetailScreen({super.key, required this.orderId, this.fromWizard = false});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  MedicalOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;
  double _userRating = 5.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingRating = false;
  bool _isCancelling = false;
  Timer? _pollingTimer;
  final ScrollController _scrollController = ScrollController();

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchDetails().then((_) {
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _reviewController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final res = await _api.dio.get('${Constants.orders}/${widget.orderId}');
      if (res.statusCode == 200 && mounted) {
        setState(() => _order = MedicalOrder.fromJson(res.data['data']));
      }
    } on DioException catch (e) {
      if (mounted) {
        if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
          setState(() => _errorMessage = 'تعذر الاتصال. تحقق من الإنترنت.');
        } else if ((e.response?.statusCode ?? 0) == 404) {
          setState(() => _errorMessage = 'الطلب غير موجود.');
        } else {
          setState(() => _errorMessage = 'فشل تحميل تفاصيل الطلب. اسحب للمحاولة مرة أخرى.');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'حدث خطأ غير متوقع.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOrder() async {
    final c = context.colors;
    final isOnWay = _order?.status == 'on_way';
    final double transferFee = (_order?.pricing?['transferFee'] ?? 150.0).toDouble();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Icon(Icons.cancel_outlined, color: c.error, size: 48),
            const SizedBox(height: 12),
            Text(isOnWay ? 'إلغاء مع فرض رسوم!' : 'إلغاء الطلب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text(
                isOnWay
                    ? 'لقد تحرك فريق المركز بالفعل نحو موقعك. عند الإلغاء الآن سيتم فرض رسوم الانتقال وقدرها ($transferFee جنيه).'
                    : 'هل أنت متأكد من إلغاء هذا الطلب؟ لا يمكن التراجع عن هذه الخطوة.',
                style: TextStyle(fontSize: 13, color: c.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false), child: const Text('تراجع'))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('إلغاء الطلب',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo'))),
                ),
              )),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isCancelling = true);
      try {
        final res = await _api.dio.put('${Constants.orders}/${widget.orderId}/cancel');
        if (res.statusCode == 200 && mounted) {
          _showSnack('✅ تم إلغاء الطلب بنجاح', success: true);
          _fetchDetails();
        }
      } on DioException catch (e) {
        _showSnack(e.response?.data?['message'] ?? 'لا يمكن إلغاء الطلب في هذه المرحلة.', success: false);
      } catch (_) {
        _showSnack('حدث خطأ. حاول مرة أخرى.', success: false);
      } finally {
        if (mounted) setState(() => _isCancelling = false);
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_order == null) return;
      if (_order!.status == 'completed' || _order!.status == 'report_ready' || _order!.status == 'cancelled') {
        timer.cancel();
        return;
      }
      try {
        final res = await _api.dio.get('${Constants.orders}/${widget.orderId}');
        if (res.statusCode == 200 && mounted) {
          final newOrder = MedicalOrder.fromJson(res.data['data']);
          if (newOrder.status == 'completed' || newOrder.status == 'report_ready') {
            timer.cancel();
            setState(() => _order = newOrder);
            if (mounted) {
              context.go('/?completedOrderId=${widget.orderId}');
            }
          } else {
            setState(() => _order = newOrder);
          }
        }
      } catch (_) {}
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تم اكتمال الفحص 🎉',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'تم الانتهاء من الفحص الطبي بنجاح! يمكنك العودة للرئيسية أو الانتقال لنتائج الفحص مباشرة.',
          style: TextStyle(fontFamily: 'Cairo', height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/');
                  },
                  child: const Text('الرئيسية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  },
                  child: const Text('نتائج الفحص', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSubmittingComplaint = false;

  Future<void> _showComplaintSheet() async {
    final c = context.colors;
    final textCtrl = TextEditingController();
    String? localError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('تقديم شكوى بشأن هذه الزيارة ⚠️',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
                    const SizedBox(height: 12),
                    Text('يرجى كتابة تفاصيل الشكوى بوضوح وسيقوم الدعم الفني بمراجعتها والتواصل معك لحل المشكلة فوراً.',
                        style: TextStyle(fontSize: 12, color: c.textSecondary, fontFamily: 'Cairo', height: 1.5)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'اكتب تفاصيل الشكوى أو الملاحظات هنا...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 12),
                      Text(localError!, style: TextStyle(color: c.error, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: c.primary, foregroundColor: Colors.white),
                      onPressed: _isSubmittingComplaint
                          ? null
                          : () async {
                              final text = textCtrl.text.trim();
                              if (text.isEmpty) {
                                setModalState(() => localError = 'يرجى كتابة نص الشكوى');
                                return;
                              }
                              setModalState(() => _isSubmittingComplaint = true);
                              try {
                                final payload = {
                                  'orderId': widget.orderId,
                                  'text': text,
                                };
                                final res = await _api.dio.post('/complaints', data: payload);
                                if (res.statusCode == 201) {
                                  Navigator.pop(context);
                                  _showSnack('✅ تم إرسال شكواك وجاري مراجعتها من قبل الإدارة', success: true);
                                }
                              } on DioException catch (e) {
                                setModalState(() {
                                  localError = e.response?.data?['message'] ?? 'فشل تسجيل الشكوى';
                                  _isSubmittingComplaint = false;
                                });
                              } catch (_) {
                                setModalState(() {
                                  localError = 'حدث خطأ غير متوقع';
                                  _isSubmittingComplaint = false;
                                });
                              }
                            },
                      child: _isSubmittingComplaint
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('إرسال الشكوى للأدمن'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmittingRating = true);
    try {
      final res = await _api.dio.post('${Constants.orders}/${widget.orderId}/rate', data: {
        'rating': _userRating.toInt(),
        'review': _reviewController.text.trim(),
      });
      if (res.statusCode == 200 && mounted) {
        _showSnack('⭐ شكراً لتقييمك!', success: true);
        _fetchDetails();
      }
    } on DioException catch (e) {
      _showSnack(e.response?.data?['message'] ?? 'فشل إرسال التقييم.', success: false);
    } catch (_) {
      _showSnack('حدث خطأ. حاول مرة أخرى.', success: false);
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(fontFamily: 'Cairo', color: success ? c.success : c.error)),
      backgroundColor: success ? c.successBg : c.errorBg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          title: Text(_order?.orderNumber ?? 'تفاصيل الطلب',
              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchDetails,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: RefreshIndicator(
          color: c.primary,
          backgroundColor: c.surface,
          onRefresh: _fetchDetails,
          child: _isLoading
              ? _buildSkeleton()
              : _errorMessage != null
                  ? _buildErrorState()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AnimatedSkeletonBox(height: 120, radius: 20, colors: c),
        const SizedBox(height: 12),
        _AnimatedSkeletonBox(height: 80, radius: 16, colors: c),
        const SizedBox(height: 12),
        _AnimatedSkeletonBox(height: 140, radius: 16, colors: c),
        const SizedBox(height: 12),
        _AnimatedSkeletonBox(height: 100, radius: 16, colors: c),
      ],
    );
  }

  Widget _buildErrorState() {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: c.errorBg, borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.error_outline_rounded, color: c.error, size: 36),
            ),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: TextStyle(fontSize: 15, color: c.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _fetchDetails,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12),
                    boxShadow: c.primaryGlow),
                child: const Text('إعادة المحاولة',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final c = context.colors;
    final isDark = context.isDark;
    final order = _order!;
    final statusColor = AppColors.getStatusColor(order.status);
    final statusBg    = AppColors.getStatusBgColor(order.status, dark: isDark);
    final statusLabel = AppColors.getStatusLabel(order.status);

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // ─── Status Header ────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.3)),
            boxShadow: isDark ? [] : c.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(18)),
                child: Icon(_getStatusIcon(order.status), color: statusColor, size: 32),
              ),
              const SizedBox(height: 12),
              Text(statusLabel,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: statusColor)),
              const SizedBox(height: 4),
              Text('${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                  style: TextStyle(fontSize: 12, color: c.textMuted, fontFamily: 'Inter')),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── Services & Price ─────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(icon: Icons.science_rounded, title: 'الفحوصات المطلوبة'),
              const SizedBox(height: 12),
              ...order.services.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(width: 6, height: 6,
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(s.nameAr,
                          style: TextStyle(fontSize: 14, color: c.textPrimary)),
                    ]),
                    Text('${s.price} ج.م',
                        style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'Inter')),
                  ],
                ),
              )),
              Container(height: 1, color: c.borderLight, margin: const EdgeInsets.symmetric(vertical: 12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الإجمالي',
                      style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary)),
                  Text('${order.pricing?['total'] ?? 0} ج.م',
                      style: TextStyle(fontWeight: FontWeight.w700, color: c.accent, fontSize: 17, fontFamily: 'Inter')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── Location ─────────────────────────────────────
        if (order.location != null)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(icon: Icons.location_on_rounded, title: 'موقع الزيارة'),
                const SizedBox(height: 12),
                _InfoRow('المنطقة', order.location!['district'] ?? '-'),
                _InfoRow('الشارع', order.location!['street'] ?? '-'),
                if (order.location!['floor'] != null)
                  _InfoRow('الطابق', '${order.location!['floor']}'),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // ─── Technician ───────────────────────────────────
        if (order.technician != null) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(icon: Icons.engineering_rounded, title: 'فريق زيارة المركز'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(order.technician!.photo ?? 'https://placehold.co/150x150.png'),
                      onBackgroundImageError: (_, __) {},
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.technician!.name,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.textPrimary)),
                        const SizedBox(height: 4),
                        Text(order.technician!.phone,
                            style: TextStyle(fontSize: 12, color: c.textSecondary, fontFamily: 'Inter')),
                      ],
                    )),
                    Row(children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text('${order.technician!.rating}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Inter', color: c.textPrimary)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ─── Report (Pending Approval) ──────────────────────
        if ((order.status == 'completed' || order.status == 'report_ready') && !order.isResultsApproved) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(icon: Icons.hourglass_empty_rounded, title: 'التقرير الطبي والنتائج'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.warningBg.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.warning.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: c.warning, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'جاري مراجعة وكتابة التقرير النهائي من قبل الإدارة وسوف يظهر هنا فور اعتماده ونشره.',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: c.warning, height: 1.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ─── Report (Approved & Ready) ─────────────────────
        if ((order.status == 'completed' || order.status == 'report_ready') && order.isResultsApproved && order.report != null) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(icon: Icons.insert_drive_file_rounded, title: 'التقرير الطبي'),
                const SizedBox(height: 12),
                if (order.report!.images.isNotEmpty) ...[
                  Text('الصور (${order.report!.images.length})',
                      style: TextStyle(fontSize: 12, color: c.textMuted)),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: order.report!.images.length,
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(order.report!.images[i], fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: c.surfaceVariant,
                              child: Icon(Icons.broken_image_rounded, color: c.textMuted))),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (order.report!.pdf != null)
                  GestureDetector(
                    onTap: () => _showSnack('سيتم دعم عرض PDF قريباً', success: true),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.successBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, color: c.success, size: 20),
                          const SizedBox(width: 8),
                          Text('تحميل تقرير PDF',
                              style: TextStyle(color: c.success, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ─── Rating ───────────────────────────────────────
        if ((order.status == 'completed' || order.status == 'report_ready') && order.technicianRating == null) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(icon: Icons.star_rounded, title: 'تقييم زيارة المركز'),
                const SizedBox(height: 12),
                Text('كيف كانت تجربتك مع فريق زيارة المركز؟',
                    style: TextStyle(fontSize: 13, color: c.textSecondary)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final v = i + 1;
                    return IconButton(
                      icon: Icon(Icons.star_rounded,
                          color: _userRating >= v ? Colors.amber : c.surfaceVariant, size: 36),
                      onPressed: () => setState(() => _userRating = v.toDouble()),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reviewController,
                  maxLines: 2,
                  style: TextStyle(color: c.textPrimary),
                  decoration: const InputDecoration(hintText: 'اكتب مراجعتك هنا...'),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _isSubmittingRating ? null : _submitRating,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isSubmittingRating ? c.surfaceVariant : c.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _isSubmittingRating ? [] : c.primaryGlow,
                    ),
                    child: Center(
                      child: _isSubmittingRating
                          ? SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
                          : const Text('إرسال التقييم',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ─── Timeline ─────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(icon: Icons.timeline_rounded, title: 'سجل الطلب'),
              const SizedBox(height: 12),
              ...order.statusHistory.map((log) {
                final sc = AppColors.getStatusColor(log.status);
                final isLast = log == order.statusHistory.last;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(children: [
                        Container(width: 10, height: 10,
                            decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
                        if (!isLast)
                          Container(width: 2, height: 24,
                              color: context.colors.borderLight),
                      ]),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppColors.getStatusLabel(log.status),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary)),
                          if (log.note != null)
                            Text(log.note!,
                                style: TextStyle(fontSize: 11, color: context.colors.textSecondary)),
                        ],
                      )),
                      Text(
                        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: context.colors.textMuted, fontFamily: 'Inter'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── Cancel Button ────────────────────────────────
        if (order.status == 'pending' || order.status == 'accepted' || order.status == 'assigned' || order.status == 'on_way') ...[
          GestureDetector(
            onTap: _isCancelling ? null : _cancelOrder,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: c.errorBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.error.withOpacity(0.4)),
              ),
              child: Center(
                child: _isCancelling
                    ? SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.error))
                    : Text('إلغاء الطلب',
                        style: TextStyle(color: c.error, fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo', fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ─── Complaints Button ────────────────────────────
        OutlinedButton.icon(
          onPressed: _showComplaintSheet,
          icon: Icon(Icons.warning_amber_rounded, color: c.error, size: 18),
          label: const Text('تقديم شكوى أو اعتراض', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: BorderSide(color: c.error.withOpacity(0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':                     return Icons.hourglass_top_rounded;
      case 'accepted': case 'assigned':  return Icons.assignment_ind_rounded;
      case 'on_way':                      return Icons.directions_car_rounded;
      case 'arrived':                     return Icons.location_on_rounded;
      case 'in_progress':                 return Icons.medical_services_rounded;
      case 'completed':                   return Icons.check_circle_rounded;
      case 'report_ready':                return Icons.insert_drive_file_rounded;
      case 'cancelled':                   return Icons.cancel_rounded;
      default:                            return Icons.help_outline_rounded;
    }
  }
}

// ── Animated Skeleton Box ───────────────────────────────────────
class _AnimatedSkeletonBox extends StatefulWidget {
  final double height, radius;
  final AppColorTokens colors;
  const _AnimatedSkeletonBox({required this.height, required this.radius, required this.colors});
  @override State<_AnimatedSkeletonBox> createState() => _AnimatedSkeletonBoxState();
}

class _AnimatedSkeletonBoxState extends State<_AnimatedSkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(widget.colors.skeletonBase, widget.colors.skeletonHighlight, _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ── Shared Card Component ────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: isDark ? [] : c.cardShadow,
      ),
      child: child,
    );
  }
}

// ── Section Title Component ──────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Icon(icon, size: 16, color: c.primary),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
    ]);
  }
}

// ── Info Row Component ───────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: TextStyle(fontSize: 12, color: c.textMuted))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: c.textPrimary))),
        ],
      ),
    );
  }
}

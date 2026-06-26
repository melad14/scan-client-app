import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/order.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/theme/app_colors.dart';
import 'package:dio/dio.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentTab = 0;
  String _patientName = 'المريض';

  // Orders state
  List<MedicalOrder> _orders = [];
  bool _isLoadingOrders = false;
  String? _ordersError;
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  final _api = ApiClient();
  late AnimationController _tabAnimController;
  late Animation<double> _tabFade;

  @override
  void initState() {
    super.initState();
    _tabAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _tabFade = CurvedAnimation(parent: _tabAnimController, curve: Curves.easeOut);
    _tabAnimController.forward();
    _loadUserInfo();
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final userData = await StorageService.getUserData();
    if (userData != null && mounted) {
      setState(() => _patientName = userData['name'] ?? 'المريض');
    }
  }

  Future<void> _fetchOrders() async {
    setState(() { _isLoadingOrders = true; _ordersError = null; });
    try {
      final endpoint = '${Constants.ordersHistory}?status=$_statusFilter&search=${_searchController.text}';
      final res = await _api.dio.get(endpoint);
      if (res.statusCode == 200) {
        final List list = res.data['data'] ?? [];
        if (mounted) setState(() => _orders = list.map((item) => MedicalOrder.fromJson(item)).toList());
      }
    } on DioException catch (e) {
      if (mounted) {
        if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
          setState(() => _ordersError = 'تعذر الاتصال. تحقق من الإنترنت.');
        } else if ((e.response?.statusCode ?? 0) >= 500) {
          setState(() => _ordersError = 'خطأ في الخادم. اسحب للأسفل للإعادة.');
        } else {
          setState(() => _ordersError = 'حدث خطأ أثناء تحميل الطلبات.');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _ordersError = 'حدث خطأ غير متوقع.');
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('تسجيل الخروج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('خروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 15))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try { await _api.dio.post(Constants.logout); } catch (_) {}
      await StorageService.clearAll();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: _buildBottomNav(),
        body: FadeTransition(
          opacity: _tabFade,
          child: _currentTab == 0 ? _buildHomeTab() : _buildHistoryTab(),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTab,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        onTap: (i) {
          setState(() => _currentTab = i);
          _tabAnimController.forward(from: 0);
          if (i == 1) _fetchOrders();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'طلباتي'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  HOME TAB
  // ════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _loadUserInfo,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Gradient Header ──────────────────────────────
          SliverToBoxAdapter(child: _buildHeroHeader()),

          // ── Services Section ──────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text('اختر الخدمة المطلوبة',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                _ServiceCard(title: 'أشعة سينية', subtitle: 'X-Ray', icon: Icons.monitor_heart_rounded,
                    color: AppColors.primary, gradient: AppColors.primaryGradient,
                    onTap: () => context.push('/orders/create?category=xray')),
                _ServiceCard(title: 'إيكو قلب', subtitle: 'Echo', icon: Icons.favorite_rounded,
                    color: const Color(0xFF64B5F6),
                    gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF64B5F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    onTap: () => context.push('/orders/create?category=xray')),
                _ServiceCard(title: 'رسم قلب', subtitle: 'ECG', icon: Icons.show_chart_rounded,
                    color: const Color(0xFFFFB347),
                    gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFFB347)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    onTap: () => context.push('/orders/create?category=xray')),
                _ServiceCard(title: 'تحاليل طبية', subtitle: 'Lab Tests', icon: Icons.science_rounded,
                    color: const Color(0xFF81C784),
                    gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF81C784)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    onTap: () => context.push('/orders/create?category=lab')),
              ]),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
            ),
          ),

          // ── Info Banner ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderGlow),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 12),
                    Expanded(child: Text('الأسعار تظهر قبل التأكيد. الدفع عند الزيارة نقداً.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0D40), Color(0xFF0F2D40), Color(0xFF0F0F1A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  ShaderMask(
                    shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                    child: const Text('سكان جو', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _logout,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('👋 ', style: TextStyle(fontSize: 24)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(text: 'أهلاً، ', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontFamily: 'Cairo')),
                      TextSpan(text: _patientName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('احجز فحصك وهيجيلك الفني في بيتك 🏠',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  HISTORY TAB
  // ════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    return Column(
      children: [
        // ── App Bar ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
          color: AppColors.surface,
          child: Column(
            children: [
              const Text('طلباتي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      onSubmitted: (_) => _fetchOrders(),
                      decoration: const InputDecoration(
                        hintText: 'ابحث برقم الطلب...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: AppColors.surfaceElevated,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textPrimary),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 18),
                        onChanged: (v) { setState(() => _statusFilter = v!); _fetchOrders(); },
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('الكل')),
                          DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')),
                          DropdownMenuItem(value: 'assigned', child: Text('معين')),
                          DropdownMenuItem(value: 'completed', child: Text('اكتمل')),
                          DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── List ───────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: _fetchOrders,
            child: _isLoadingOrders
                ? _buildSkeletonList()
                : _ordersError != null
                    ? _buildErrorState(_ordersError!)
                    : _orders.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _orders.length,
                            padding: const EdgeInsets.all(20),
                            itemBuilder: (_, i) => _OrderCard(order: _orders[i]),
                          ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 4,
      padding: const EdgeInsets.all(20),
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _skeleton(width: 120, height: 16),
              _skeleton(width: 80, height: 24, radius: 20),
            ]),
            const SizedBox(height: 14),
            _skeleton(width: 200, height: 14),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _skeleton(width: 100, height: 12),
              _skeleton(width: 60, height: 14),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _skeleton({required double width, required double height, double radius = 8}) => Container(
    width: width, height: height,
    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(radius)),
  );

  Widget _buildErrorState(String message) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(message, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('↑ اسحب للأسفل لإعادة المحاولة',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _fetchOrders,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                      child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text('لا توجد طلبات بعد',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('طلباتك الطبية هتظهر هنا بعد أول حجز',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.7), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('↑ اسحب للأسفل للتحديث',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => setState(() { _currentTab = 0; _tabAnimController.forward(from: 0); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14), boxShadow: AppColors.primaryGlow),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('اطلب خدمة الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Service Card
// ══════════════════════════════════════════════════════════
class _ServiceCard extends StatefulWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _ServiceCard({required this.title, required this.subtitle, required this.icon,
    required this.color, required this.gradient, required this.onTap});
  @override State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withOpacity(0.3)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(gradient: widget.gradient, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                const Spacer(),
                Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(widget.subtitle, style: TextStyle(fontSize: 11, color: widget.color, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Order Card
// ══════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final MedicalOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.getStatusColor(order.status);
    final statusBg = AppColors.getStatusBgColor(order.status);
    final statusLabel = AppColors.getStatusLabel(order.status);

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14, fontFamily: 'Inter')),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(order.services.map((s) => s.nameAr).join(' + '),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Inter')),
                ]),
                Text('${order.pricing?['total'] ?? 0} ج.م',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent, fontSize: 15, fontFamily: 'Inter')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

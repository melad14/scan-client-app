import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/order.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/services/notification_service.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/theme/app_colors.dart';
import 'package:patient_app/core/theme/theme_provider.dart';
import 'package:dio/dio.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
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
    
    // Register FCM Device Token for notifications
    NotificationService.registerDeviceToken();
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
    final c = context.colors;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: c.errorBg, borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.logout_rounded, color: c.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text('تسجيل الخروج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                style: TextStyle(fontSize: 14, color: c.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء'))),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(14)),
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
    final isDark = context.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: context.colors.background,
        bottomNavigationBar: _buildBottomNav(),
        body: FadeTransition(
          opacity: _tabFade,
          child: _currentTab == 0 ? _buildHomeTab() : _buildHistoryTab(),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 1)),
        boxShadow: context.isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTab,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: c.primary,
        unselectedItemColor: c.textMuted,
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
    final c = context.colors;
    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: _loadUserInfo,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Hero Header ──────────────────────────────────
          SliverToBoxAdapter(child: _buildHeroHeader()),

          // ── Services Section Title ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 20,
                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  Text('اختر الخدمة المطلوبة',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
                ],
              ),
            ),
          ),

          // ── Service Cards Grid (2×2) ────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                _ServiceCard(
                  title: 'أشعة سينية',
                  subtitle: 'X-Ray',
                  icon: Icons.monitor_heart_rounded,
                  iconBg: c.primaryLight,
                  iconColor: c.primary,
                  onTap: () => context.push('/orders/create?category=xray'),
                ),
                _ServiceCard(
                  title: 'إيكو قلب',
                  subtitle: 'Echo',
                  icon: Icons.favorite_rounded,
                  iconBg: const Color(0xFFE6F0FA),
                  iconColor: const Color(0xFF2B7EC2),
                  onTap: () => context.push('/orders/create?category=xray'),
                ),
                _ServiceCard(
                  title: 'رسم قلب',
                  subtitle: 'ECG',
                  icon: Icons.show_chart_rounded,
                  iconBg: const Color(0xFFFEF3E2),
                  iconColor: const Color(0xFFD97B0A),
                  onTap: () => context.push('/orders/create?category=xray'),
                ),
                _ServiceCard(
                  title: 'تحاليل طبية',
                  subtitle: 'Lab Tests',
                  icon: Icons.science_rounded,
                  iconBg: const Color(0xFFEFF6E8),
                  iconColor: const Color(0xFF4D8C2C),
                  onTap: () => context.push('/orders/create?category=lab'),
                ),
              ]),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
            ),
          ),

          // ── Info Banner ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: c.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: c.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      'الأسعار تظهر قبل التأكيد. الدفع عند الزيارة نقداً.',
                      style: TextStyle(fontSize: 13, color: c.primaryDeep, height: 1.6),
                    )),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    final c = context.colors;
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0A0F1E), const Color(0xFF0F1729)]
              : [const Color(0xFF085041), const Color(0xFF1D9E75)],
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
              // ── Logo ─────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('سكان جو',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
                ],
              ),

              // ── Actions (Theme Toggle + Logout) ──────────
              Row(
                children: [
                  // Theme Toggle Button
                  _ThemeToggleButton(),
                  const SizedBox(width: 8),
                  // Logout Button
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Greeting ─────────────────────────────────────
          Row(
            children: [
              const Text('👋 ', style: TextStyle(fontSize: 22)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(text: 'أهلاً، ',
                          style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 16, fontFamily: 'Cairo')),
                      TextSpan(text: _patientName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('احجز فحصك وهيجيلك الفني في بيتك 🏠',
              style: TextStyle(fontSize: 14, color: Color(0xCCFFFFFF), height: 1.6)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  HISTORY TAB
  // ════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    final c = context.colors;
    return Column(
      children: [
        // ── App Bar ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border)),
            boxShadow: context.isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Text('طلباتي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: c.textPrimary, fontSize: 14),
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
                      color: c.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: c.surfaceElevated,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: c.textPrimary),
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted, size: 18),
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

        // ── List ─────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            backgroundColor: c.surface,
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
    final c = context.colors;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 4,
      padding: const EdgeInsets.all(20),
      itemBuilder: (_, __) => _SkeletonCard(colors: c),
    );
  }

  Widget _buildErrorState(String message) {
    final c = context.colors;
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
                    decoration: BoxDecoration(color: c.errorBg, borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.wifi_off_rounded, color: c.error, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(message, style: TextStyle(fontSize: 15, color: c.textSecondary), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('↑ اسحب للأسفل لإعادة المحاولة', style: TextStyle(fontSize: 11, color: c.textMuted)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _fetchOrders,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12),
                          boxShadow: c.primaryGlow),
                      child: const Text('إعادة المحاولة',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
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
    final c = context.colors;
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
                    decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(24)),
                    child: Icon(Icons.receipt_long_rounded, color: c.primary, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text('لا توجد طلبات بعد',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  const SizedBox(height: 8),
                  Text('طلباتك الطبية هتظهر هنا بعد أول حجز',
                      style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.7), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text('↑ اسحب للأسفل للتحديث', style: TextStyle(fontSize: 11, color: c.textMuted)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => setState(() { _currentTab = 0; _tabAnimController.forward(from: 0); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: c.primaryGlow,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('اطلب خدمة الآن',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 15)),
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
//  Theme Toggle Button
// ══════════════════════════════════════════════════════════
class _ThemeToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    return GestureDetector(
      onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Skeleton Card
// ══════════════════════════════════════════════════════════
class _SkeletonCard extends StatefulWidget {
  final AppColorTokens colors;
  const _SkeletonCard({required this.colors});
  @override State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
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
    final c = widget.colors;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = Color.lerp(c.skeletonBase, c.skeletonHighlight, _anim.value)!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _bar(shimmer, 120, 16),
              _bar(shimmer, 80, 24, radius: 20),
            ]),
            const SizedBox(height: 14),
            _bar(shimmer, 200, 14),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _bar(shimmer, 100, 12),
              _bar(shimmer, 60, 14),
            ]),
          ]),
        );
      },
    );
  }

  Widget _bar(Color color, double w, double h, {double radius = 8}) =>
      Container(width: w, height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)));
}

// ══════════════════════════════════════════════════════════
//  Service Card — clean, no gradient, icon on teal circle
// ══════════════════════════════════════════════════════════
class _ServiceCard extends StatefulWidget {
  final String title, subtitle;
  final IconData icon;
  final Color iconBg, iconColor;
  final VoidCallback onTap;
  const _ServiceCard({
    required this.title, required this.subtitle, required this.icon,
    required this.iconBg, required this.iconColor, required this.onTap,
  });
  @override State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _pressed ? c.primary.withOpacity(0.4) : c.border),
            boxShadow: isDark ? [] : c.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? widget.iconColor.withOpacity(0.15) : widget.iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 26),
                ),
                const Spacer(),
                Text(widget.title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(widget.subtitle,
                    style: TextStyle(fontSize: 11, color: widget.iconColor, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
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
    final c = context.colors;
    final isDark = context.isDark;
    final statusColor = AppColors.getStatusColor(order.status);
    final statusBg    = AppColors.getStatusBgColor(order.status, dark: isDark);
    final statusLabel = AppColors.getStatusLabel(order.status);

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
          boxShadow: isDark ? [] : c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.orderNumber,
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.primary, fontSize: 14, fontFamily: 'Inter')),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            Text(
              order.services.map((s) => s.nameAr).join(' + '),
              style: TextStyle(color: c.textSecondary, fontSize: 13),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: c.borderLight),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: c.textMuted),
                  const SizedBox(width: 4),
                  Text('${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                      style: TextStyle(fontSize: 12, color: c.textMuted, fontFamily: 'Inter')),
                ]),
                Text('${order.pricing?['total'] ?? 0} ج.م',
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.accent, fontSize: 15, fontFamily: 'Inter')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

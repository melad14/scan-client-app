import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/order.dart';
import 'package:patient_app/core/models/category.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/services/notification_service.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/theme/app_colors.dart';
import 'package:patient_app/core/theme/theme_provider.dart';
import 'package:patient_app/core/theme/ui_components.dart';
import 'package:patient_app/features/profile/profile_screen.dart';
import 'package:dio/dio.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String? completedOrderId;
  const HomeScreen({super.key, this.completedOrderId});

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

  // Categories state
  List<ServiceCategory> _categories = [];
  bool _isLoadingCategories = false;
  String? _categoriesError;

  String? _lastShownCompletedOrderId;
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
    _fetchCategories();
    _fetchOrders();
    
    // Register FCM Device Token for notifications
    NotificationService.registerDeviceToken();
    _checkCompletedOrder();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkCompletedOrder();
  }

  void _checkCompletedOrder() {
    if (widget.completedOrderId != null && widget.completedOrderId != _lastShownCompletedOrderId) {
      _lastShownCompletedOrderId = widget.completedOrderId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompletedOrderDialog(widget.completedOrderId!);
      });
    }
  }

  void _showCompletedOrderDialog(String orderId) {
    final c = context.colors;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تم اكتمال الفحص 🎉',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
            SizedBox(height: 16),
            Text(
              'تم الانتهاء من الفحص الطبي ورفع النتائج بنجاح! هل تريد عرض نتائج الفحص الآن؟',
              style: TextStyle(fontFamily: 'Cairo', height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
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
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/');
                    context.push('/orders/$orderId');
                  },
                  child: const Text('عرض النتائج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;
    setState(() { _isLoadingCategories = true; _categoriesError = null; });
    try {
      final res = await _api.dio.get(Constants.categories);
      if (res.statusCode == 200) {
        final List list = res.data['data'] ?? [];
        if (mounted) {
          setState(() {
            _categories = list.map((item) => ServiceCategory.fromJson(item)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
      if (mounted) setState(() => _categoriesError = 'تعذر تحميل التصنيفات');
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
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
    // Try to load cached orders first to show them immediately
    if (_orders.isEmpty) {
      final cached = await StorageService.getCachedOrders();
      if (cached != null && mounted) {
        setState(() {
          _orders = cached.map((item) => MedicalOrder.fromJson(item)).toList();
        });
      }
    }

    setState(() { _isLoadingOrders = true; _ordersError = null; });
    try {
      final endpoint = '${Constants.ordersHistory}?status=$_statusFilter&search=${_searchController.text}';
      final res = await _api.dio.get(endpoint);
      if (res.statusCode == 200) {
        final List list = res.data['data'] ?? [];
        if (mounted) {
          setState(() {
            _orders = list.map((item) => MedicalOrder.fromJson(item)).toList();
          });
        }
        // Save to cache
        await StorageService.saveCachedOrders(list);
      }
    } on DioException catch (e) {
      if (mounted) {
        if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
          if (_orders.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('أنت غير متصل بالإنترنت. يتم عرض البيانات المحفوظة محلياً.')),
            );
          } else {
            setState(() => _ordersError = 'تعذر الاتصال. تحقق من الإنترنت.');
          }
        } else if ((e.response?.statusCode ?? 0) >= 500) {
          if (_orders.isEmpty) setState(() => _ordersError = 'خطأ في الخادم. اسحب للأسفل للإعادة.');
        } else {
          if (_orders.isEmpty) setState(() => _ordersError = 'حدث خطأ أثناء تحميل الطلبات.');
        }
      }
    } catch (_) {
      if (mounted && _orders.isEmpty) setState(() => _ordersError = 'حدث خطأ غير متوقع.');
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
          child: _currentTab == 0
              ? _buildHomeTab()
              : _currentTab == 1
                  ? _buildHistoryTab()
                  : const ProfileScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'السجل المرضي'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'حسابي'),
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
      onRefresh: () async {
        await _loadUserInfo();
        await _fetchCategories();
      },
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

          // ── Prescription Upload Card (New) ────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GestureDetector(
                onTap: () => context.push('/orders/create?category=prescription_only'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.primary, c.primaryDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: c.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.note_add_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'مش عارف فحصك؟ احجز بالروشتة مباشرة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ارفع صورة الروشتة وسنتصل بك لتأكيد طلبك وتحديد الفحص والسعر',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 11,
                                height: 1.5,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Service Cards Grid (Dynamic) ────────────────────
          if (_isLoadingCategories)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(60.0),
                child: Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                    ),
                  ),
                ),
              ),
            )
          else if (_categoriesError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: ErrorStateWidget(
                  message: _categoriesError!,
                  onRetry: _fetchCategories,
                ),
              ),
            )
          else if (_categories.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: EmptyStateWidget(
                  icon: Icons.grid_view_rounded,
                  title: 'لا توجد أقسام متاحة',
                  description: 'لا توجد تخصصات أو خدمات مفعلة حالياً في التطبيق. يرجى التحقق لاحقاً.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = _categories[index];
                    return _ServiceCard(
                      title: cat.nameAr,
                      subtitle: cat.nameEn,
                      icon: cat.getIconData(),
                      iconBg: cat.parseBgColor(),
                      iconColor: cat.parseColor(),
                      onTap: () => context.push('/orders/create?category=${cat.key}'),
                    );
                  },
                  childCount: _categories.length,
                ),
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
          const Text('احجز فحصك وهيجيلك فريق المركز لغاية البيت 🏠',
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
              Text('السجل المرضي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
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
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ErrorStateWidget(
              message: message,
              onRetry: _fetchOrders,
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
            child: EmptyStateWidget(
              icon: Icons.receipt_long_rounded,
              title: 'لا توجد طلبات بعد',
              description: 'طلباتك الطبية والزيارات المحجوزة ستظهر هنا بعد أول عملية حجز.',
              actionLabel: 'تصفح الخدمات والتحاليل',
              onAction: () {
                // Switch to home services tab (Tab 0)
                setState(() { _currentTab = 0; });
              },
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

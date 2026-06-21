import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/order.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  String _patientName = 'المريض';
  
  // Orders history state
  List<MedicalOrder> _orders = [];
  bool _isLoadingOrders = false;
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchOrders();
  }

  Future<void> _loadUserInfo() async {
    final userData = await StorageService.getUserData();
    if (userData != null) {
      setState(() => _patientName = userData['name'] ?? 'المريض');
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final endpoint = '${Constants.ordersHistory}?status=$_statusFilter&search=${_searchController.text}';
      final res = await _api.dio.get(endpoint);
      if (res.statusCode == 200) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _orders = list.map((item) => MedicalOrder.fromJson(item)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    } finally {
      setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _logout() async {
    final confirmation = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'تسجيل الخروج',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    child: const Text('تسجيل الخروج'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (confirmation == true) {
      try {
        await _api.dio.post(Constants.logout);
      } catch (_) {}
      await StorageService.clearAll();
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTab == 0 ? 'سكان جو' : 'طلباتي السابقة'),
        leading: _currentTab == 0
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() => _currentTab = index);
          if (index == 1) _fetchOrders();
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'طلباتي',
          ),
        ],
      ),
      body: _currentTab == 0 ? _buildHomeTab() : _buildHistoryTab(),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HOME TAB — Light, warm, clean service cards
  // ════════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Welcome Card ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryDeep,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.waving_hand_rounded, color: Color(0xFFFBBF24), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'أهلاً، $_patientName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'احجز فحص أشعة أو تحاليل وهيوصلك فني متخصص لحد بيتك.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xBBFFFFFF),
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ─── Section Title ──────────────────────────────
          const Text(
            'اختر نوع الخدمة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // ─── Service Cards — 2×2 Grid ───────────────────
          Row(
            children: [
              Expanded(
                child: _ServiceCard(
                  title: 'أشعة سينية',
                  subtitle: 'X-Ray',
                  icon: Icons.monitor_heart_rounded,
                  color: AppColors.primary,
                  onTap: () => context.push('/orders/create?category=xray'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ServiceCard(
                  title: 'إيكو',
                  subtitle: 'Echo',
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFF2B7EC2),
                  onTap: () => context.push('/orders/create?category=xray'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ServiceCard(
                  title: 'رسم قلب',
                  subtitle: 'ECG',
                  icon: Icons.show_chart_rounded,
                  color: const Color(0xFFD97B0A),
                  onTap: () => context.push('/orders/create?category=xray'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ServiceCard(
                  title: 'تحاليل طبية',
                  subtitle: 'Lab Tests',
                  icon: Icons.science_rounded,
                  color: const Color(0xFF4D8C2C),
                  onTap: () => context.push('/orders/create?category=lab'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ─── Quick Info ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'الأسعار تظهر قبل التأكيد. الدفع عند الزيارة.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.info,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HISTORY TAB — Clean order cards with status badges
  // ════════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    return Column(
      children: [
        // ─── Filter Bar ───────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _fetchOrders(),
                  decoration: const InputDecoration(
                    hintText: 'ابحث برقم الطلب...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    onChanged: (val) {
                      setState(() => _statusFilter = val!);
                      _fetchOrders();
                    },
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('الكل')),
                      DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')),
                      DropdownMenuItem(value: 'assigned', child: Text('تم التعيين')),
                      DropdownMenuItem(value: 'completed', child: Text('اكتمل')),
                      DropdownMenuItem(value: 'report_ready', child: Text('التقرير جاهز')),
                      DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Orders List ──────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _fetchOrders,
            child: _isLoadingOrders
                ? _buildSkeletonList()
                : _orders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _orders.length,
                        padding: const EdgeInsets.all(20),
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return _OrderCard(order: order);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  // ─── Skeleton Loader (not spinner!) ───────────────────────
  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.all(20),
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _skeleton(width: 120, height: 16),
                _skeleton(width: 80, height: 24, radius: 20),
              ],
            ),
            const SizedBox(height: 12),
            _skeleton(width: 200, height: 14),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _skeleton(width: 140, height: 12),
                _skeleton(width: 60, height: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeleton({required double width, required double height, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.warmBackground,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد طلبات سابقة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'طلباتك الطبية هتظهر هنا بعد ما تحجز أول خدمة',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentTab = 0),
              icon: const Icon(Icons.add_rounded),
              label: const Text('اطلب خدمة جديدة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  COMPONENTS — Service Card
// ══════════════════════════════════════════════════════════════
class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  COMPONENTS — Order Card (History Tab)
// ══════════════════════════════════════════════════════════════
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header: Order # + Status Badge ─────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.orderNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontFamily: 'Inter',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ─── Services ───────────────────────────────
            Text(
              order.services.map((s) => s.nameAr).join(' + '),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),

            // ─── Footer: Date + Price ───────────────────
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                Text(
                  '${order.pricing?['total'] ?? 0} ج.م',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 15,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

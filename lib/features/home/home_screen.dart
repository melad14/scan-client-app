import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/order.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  String _adminName = 'المريض';
  
  // Orders history state
  List<MedicalOrder> _orders = [];
  bool _isLoadingOrders = false;
  String _statusFilter = 'all';
  String _searchQuery = '';
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
      setState(() => _adminName = userData['name'] ?? 'المريض');
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final endpoint = '${Constants.ordersHistory}?status=$_statusFilter&search=$_searchQuery';
      final res = await _api.dio.get(endpoint);
      if (res.statusCode == 200) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _orders = list.map((item) => MedicalOrder.fromJson(item)).toList();
        });
      }
    } catch (e) {
      print('Error fetching orders: $e');
    } finally {
      setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _logout() async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم')),
        ],
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

  String _translateStatus(String status) {
    switch (status) {
      case 'pending': return 'انتظار مراجعة';
      case 'assigned': return 'تم قبول الطلب';
      case 'on_way': return 'في الطريق';
      case 'arrived': return 'وصل الفني';
      case 'in_progress': return 'جاري الفحص';
      case 'completed': return 'تم الفحص';
      case 'report_ready': return 'التقرير جاهز';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.amber;
      case 'assigned': return Colors.indigo;
      case 'on_way':
      case 'arrived':
      case 'in_progress': return Colors.blue;
      case 'completed':
      case 'report_ready': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTab == 0 ? 'أشعتك لخدمات المنزل' : 'طلباتي السابقة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
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
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), label: 'طلباتي السابقة'),
        ],
      ),
      body: _currentTab == 0 ? _buildHomeTab() : _buildHistoryTab(),
    );
  }

  Widget _buildHomeTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بك، $_adminName',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'احجز موعد أشعة سينية أو رسم قلب أو تحاليل طبية وسيرسل لك خبراؤنا فني متخصص إلى المنزل فوراً.',
                  style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'اختر الخدمة المطلوبة:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),

          // X-Ray Choice
          _buildServiceChoiceCard(
            title: 'أشعة منزلية متنقلة',
            subtitle: 'أشعة سينية، رسم قلب، إيكو بالمنزل',
            icon: Icons.personal_video,
            color: const Color(0xFF6366F1),
            onTap: () => context.push('/orders/create?category=xray'),
          ),
          const SizedBox(height: 16),

          // Lab Choice
          _buildServiceChoiceCard(
            title: 'سحب تحاليل طبية بالمنزل',
            subtitle: 'صورة دم كاملة، سكر، وظائف كبد وكلى',
            icon: Icons.science_outlined,
            color: const Color(0xFF10B981),
            onTap: () => context.push('/orders/create?category=lab'),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (val) {
                    setState(() => _searchQuery = val);
                    _fetchOrders();
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم الطلب...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                onChanged: (val) {
                  setState(() => _statusFilter = val!);
                  _fetchOrders();
                },
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('كل الحالات')),
                  DropdownMenuItem(value: 'pending', child: Text('انتظار مراجعة')),
                  DropdownMenuItem(value: 'assigned', child: Text('معين فني')),
                  DropdownMenuItem(value: 'completed', child: Text('تم الفحص')),
                  DropdownMenuItem(value: 'report_ready', child: Text('التقرير جاهز')),
                  DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchOrders,
            child: _isLoadingOrders
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const Center(child: Text('لا توجد طلبات سابقة لتاريخ اليوم'))
                    : ListView.builder(
                        itemCount: _orders.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return Card(
                            color: const Color(0xFF131B2E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.white.withOpacity(0.05)),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              onTap: () => context.push('/orders/${order.id}'),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    order.orderNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(order.status).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _translateStatus(order.status),
                                      style: TextStyle(
                                        color: _getStatusColor(order.status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    order.services.map((s) => s.nameAr).join(' + '),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'تاريخ الطلب: ${order.createdAt.year}-${order.createdAt.month}-${order.createdAt.day}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      Text(
                                        '${order.pricing?['total'] ?? 0} ج.م',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

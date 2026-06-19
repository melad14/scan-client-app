import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/order.dart';
import 'package:patient_app/core/utils/constants.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  MedicalOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;

  // Rating input
  double _userRating = 5.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingRating = false;

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.dio.get('${Constants.orders}/${widget.orderId}');
      if (res.statusCode == 200) {
        setState(() {
          _order = MedicalOrder.fromJson(res.data['data']);
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'فشل تحميل تفاصيل الفحص الطبي');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('إلغاء الطلب')),
        ],
      ),
    );

    if (confirmation == true) {
      setState(() => _isLoading = true);
      try {
        final res = await _api.dio.put('${Constants.orders}/${widget.orderId}/cancel');
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء الطلب بنجاح')),
          );
          _fetchDetails();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن إلغاء الطلب في هذه المرحلة')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmittingRating = true);
    try {
      final res = await _api.dio.post('${Constants.orders}/${widget.orderId}/rate', data: {
        'rating': _userRating.toInt(),
        'review': _reviewController.text.trim()
      });

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شكراً لتقييمك للفني الطبي!')),
        );
        _fetchDetails();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تسجيل التقييم')),
      );
    } finally {
      setState(() => _isSubmittingRating = false);
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending': return 'تم الاستلام وبانتظار المراجعة';
      case 'assigned': return 'تم قبول الطلب وتعيين الفني';
      case 'on_way': return 'الفني في طريقه لموقعك';
      case 'arrived': return 'وصل الفني إلى موقعك';
      case 'in_progress': return 'جاري إجراء الفحص الطبي';
      case 'completed': return 'تم إنهاء الفحص الطبي';
      case 'report_ready': return 'التقرير الطبي وصور الفحص جاهزة';
      case 'cancelled': return 'تم إلغاء الطلب';
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
        title: Text(_order != null ? _order!.orderNumber : 'تفاصيل الطلب'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header card status
                      Card(
                        color: const Color(0xFF131B2E),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                _translateStatus(_order!.status),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(_order!.status),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'تاريخ الحجز: ${_order!.createdAt.year}-${_order!.createdAt.month}-${_order!.createdAt.day}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Results & reports viewer if ready
                      if (_order!.status == 'report_ready' && _order!.report != null) ...[
                        const Text('التقرير الطبي والنتائج:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Card(
                          color: const Color(0xFF131B2E),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                if (_order!.report!.images.isNotEmpty) ...[
                                  const Text('صور الأشعة والفحص المتاحة:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                  const SizedBox(height: 12),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: _order!.report!.images.length,
                                    itemBuilder: (context, idx) {
                                      final img = _order!.report!.images[idx];
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(img, fit: BoxFit.cover),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                if (_order!.report!.pdf != null) ...[
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Simulate PDF download/open
                                    },
                                    icon: const Icon(Icons.download_outlined),
                                    label: const Text('تحميل وقراءة تقرير الـ PDF'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Assigned Technician Info
                      if (_order!.technician != null) ...[
                        const Text('الفني الطبي المعين للطلب:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Card(
                          color: const Color(0xFF131B2E),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: NetworkImage(_order!.technician!.photo ?? 'https://placehold.co/150x150.png'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _order!.technician!.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _order!.technician!.phone,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${_order!.technician!.rating}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Rating Input form
                      if ((_order!.status == 'completed' || _order!.status == 'report_ready') &&
                          _order!.technicianRating == null) ...[
                        const Text('تقييم أداء الفني الطبي:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Card(
                          color: const Color(0xFF131B2E),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('ما هو تقييمك لأداء الفني الطبي خلال زيارتك المنزلية؟', style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    final starValue = index + 1;
                                    return IconButton(
                                      icon: Icon(
                                        Icons.star,
                                        color: _userRating >= starValue ? Colors.amber : Colors.grey,
                                        size: 32,
                                      ),
                                      onPressed: () => setState(() => _userRating = starValue.toDouble()),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _reviewController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText: 'اكتب مراجعتك أو أي ملاحظات للفني...',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _isSubmittingRating ? null : _submitRating,
                                  child: const Text('تسجيل التقييم المالي والمهني'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Timeline
                      const Text('سجل وتفاصيل الحركة الزمنية للطلب:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF131B2E),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: _order!.statusHistory.map((log) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _translateStatus(log.status),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          if (log.note != null) ...[
                                            const SizedBox(height: 2),
                                            Text(log.note!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${log.timestamp.hour}:${log.timestamp.minute}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Cancel action button
                      if (_order!.status == 'pending' || _order!.status == 'assigned') ...[
                        ElevatedButton(
                          onPressed: _cancelOrder,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), foregroundColor: Colors.red),
                          child: const Text('إلغاء طلب الفحص الطبي'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }
}

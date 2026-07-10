import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/saved_address.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/theme/app_colors.dart';
import 'package:patient_app/core/theme/ui_components.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final _api = ApiClient();
  List<SavedAddress> _addresses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.dio.get(Constants.savedAddresses);
      if (res.statusCode == 200 && mounted) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _addresses = list.map((e) => SavedAddress.fromJson(e)).toList();
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['message'] ?? 'فشل تحميل العناوين المحفوظة';
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

  void _showAddEditBottomSheet({SavedAddress? address}) {
    final c = context.colors;
    final isEdit = address != null;

    final labelController = TextEditingController(text: address?.label);
    final governorateController = TextEditingController(text: address?.governorate ?? 'القاهرة');
    final districtController = TextEditingController(text: address?.district);
    final streetController = TextEditingController(text: address?.street);
    final buildingController = TextEditingController(text: address?.building);
    final floorController = TextEditingController(text: address?.floor?.toString());
    bool hasElevator = address?.hasElevator ?? false;
    
    // Address detail parts parsed from geo geocode
    String houseNumber = address?.houseNumber ?? '';
    String road = address?.road ?? '';
    String neighbourhood = address?.neighbourhood ?? '';
    String suburb = address?.suburb ?? '';
    String city = address?.city ?? '';
    String postcode = address?.postcode ?? '';
    String country = address?.country ?? 'مصر';
    String countryCode = address?.countryCode ?? 'eg';

    LatLng selectedLatLng = address?.lat != null && address?.lng != null
        ? LatLng(address!.lat!, address.lng!)
        : const LatLng(30.0444, 31.2357);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            Future<void> reverseGeocode(LatLng latLng) async {
              try {
                final response = await _api.dio.get(
                  'https://nominatim.openstreetmap.org/reverse',
                  queryParameters: {
                    'format': 'json',
                    'lat': latLng.latitude,
                    'lon': latLng.longitude,
                    'accept-language': 'ar',
                    'zoom': '18',
                    'addressdetails': '1',
                  },
                  options: Options(headers: {'User-Agent': 'ScanGoApp/1.0'}),
                );
                
                if (response.statusCode == 200 && response.data != null) {
                  final addr = response.data['address'];
                  if (addr != null && mounted) {
                    setModalState(() {
                      houseNumber = addr['house_number'] ?? '';
                      road = addr['road'] ?? addr['street'] ?? '';
                      neighbourhood = addr['neighbourhood'] ?? '';
                      suburb = addr['suburb'] ?? addr['quarter'] ?? '';
                      city = addr['city'] ?? addr['town'] ?? '';
                      final String state = addr['state'] ?? addr['governorate'] ?? 'القاهرة';
                      postcode = addr['postcode'] ?? '';
                      country = addr['country'] ?? 'مصر';
                      countryCode = addr['country_code'] ?? 'eg';

                      String detectedDistrict = addr['city_district'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? addr['town'] ?? addr['city'] ?? '';
                      detectedDistrict = detectedDistrict.replaceAll('قسم ', '').trim();
                      if (detectedDistrict.isEmpty) detectedDistrict = 'القاهرة';

                      districtController.text = detectedDistrict;
                      governorateController.text = state.replaceAll('محافظة ', '').trim();

                      final fullStreet = road + (houseNumber.isNotEmpty ? ' $houseNumber' : '');
                      if (fullStreet.isNotEmpty) {
                        streetController.text = fullStreet;
                      }
                    });
                  }
                }
              } catch (_) {}
            }

            Future<void> getCurrentLocation() async {
              try {
                bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) return;

                LocationPermission permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                  if (permission == LocationPermission.denied) return;
                }
                
                final position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                );

                final newLatLng = LatLng(position.latitude, position.longitude);
                setModalState(() {
                  selectedLatLng = newLatLng;
                });
                reverseGeocode(newLatLng);
              } catch (_) {}
            }

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
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isEdit ? 'تعديل عنوان' : 'إضافة عنوان جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Mini Map Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.border),
                        ),
                        child: Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: selectedLatLng,
                                initialZoom: 14.0,
                                onTap: (pos, latLng) {
                                  setModalState(() {
                                    selectedLatLng = latLng;
                                  });
                                  reverseGeocode(latLng);
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.scango.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: selectedLatLng,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 36),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: GestureDetector(
                                onTap: getCurrentLocation,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: c.primaryDeep,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: c.primary.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.my_location_rounded, color: c.primary, size: 14),
                                      const SizedBox(width: 6),
                                      const Text('موقعي الحالي', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo')),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        labelText: 'تسمية العنوان (مثال: البيت، بيت ماما، المكتب) *',
                        labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: c.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: governorateController,
                            decoration: InputDecoration(
                              labelText: 'المحافظة *',
                              labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary, fontSize: 13),
                              filled: true,
                              fillColor: c.surfaceVariant,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: districtController,
                            decoration: InputDecoration(
                              labelText: 'الحي / المنطقة *',
                              labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary, fontSize: 13),
                              filled: true,
                              fillColor: c.surfaceVariant,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: streetController,
                      decoration: InputDecoration(
                        labelText: 'الشارع ورقم البناية بالتفصيل *',
                        labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: c.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: buildingController,
                            decoration: InputDecoration(
                              labelText: 'رقم الشقة أو تفاصيل البناية',
                              labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary, fontSize: 13),
                              filled: true,
                              fillColor: c.surfaceVariant,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: floorController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'الطابق',
                              labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary, fontSize: 13),
                              filled: true,
                              fillColor: c.surfaceVariant,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('يوجد مصعد في البناية', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                      value: hasElevator,
                      activeColor: c.primary,
                      onChanged: (val) => setModalState(() => hasElevator = val),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        if (labelController.text.trim().isEmpty ||
                            districtController.text.trim().isEmpty ||
                            streetController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى تعبئة الحقول الأساسية')),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        setState(() => _isLoading = true);

                        final payload = {
                          'label': labelController.text.trim(),
                          'governorate': governorateController.text.trim(),
                          'district': districtController.text.trim(),
                          'street': streetController.text.trim(),
                          'building': buildingController.text.trim(),
                          'houseNumber': houseNumber,
                          'road': road,
                          'neighbourhood': neighbourhood,
                          'suburb': suburb,
                          'city': city,
                          'postcode': postcode,
                          'country': country,
                          'countryCode': countryCode,
                          'floor': int.tryParse(floorController.text.trim()),
                          'hasElevator': hasElevator,
                          'coordinates': [selectedLatLng.longitude, selectedLatLng.latitude]
                        };

                        try {
                          Response res;
                          if (isEdit) {
                            res = await _api.dio.put('${Constants.savedAddresses}/${address.id}', data: payload);
                          } else {
                            res = await _api.dio.post(Constants.savedAddresses, data: payload);
                          }

                          if (res.statusCode == 200 || res.statusCode == 201) {
                            _fetchAddresses();
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('فشل حفظ العنوان. يرجى مراجعة الاتصال والبيانات.')),
                          );
                          setState(() => _isLoading = false);
                        }
                      },
                      child: Text(
                        isEdit ? 'حفظ التعديلات' : 'إضافة العنوان',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
                      ),
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

  Future<void> _deleteAddress(SavedAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف العنوان "${address.label}"؟', style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final res = await _api.dio.delete('${Constants.savedAddresses}/${address.id}');
        if (res.statusCode == 200) {
          _fetchAddresses();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل حذف العنوان')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _makeDefault(SavedAddress address) async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.dio.put('${Constants.savedAddresses}/${address.id}/default');
      if (res.statusCode == 200) {
        _fetchAddresses();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تعيين العنوان كافتراضي')),
      );
      setState(() => _isLoading = false);
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
            'العناوين المحفوظة',
            style: TextStyle(color: c.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
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
                  onRetry: _fetchAddresses,
                )
              : _addresses.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.location_on_outlined,
                      title: 'لا توجد عناوين محفوظة',
                      description: 'قم بإضافة عناوين منزلك أو عملك لتتمكن من تحديد موقع زيارة فريق المركز بسهولة.',
                      actionLabel: 'إضافة عنوان جديد +',
                      onAction: () => _showAddEditBottomSheet(),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _addresses.length,
                      itemBuilder: (context, index) {
                        final a = _addresses[index];
                        IconData iconData = Icons.home_rounded;
                        if (a.icon == 'work') iconData = Icons.work_rounded;
                        if (a.icon == 'hospital') iconData = Icons.local_hospital_rounded;
                        if (a.icon == 'family') iconData = Icons.family_restroom_rounded;

                        return Card(
                          color: c.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: a.isDefault ? c.primary : c.borderLight,
                              width: a.isDefault ? 1.5 : 1,
                            ),
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
                                    Row(
                                      children: [
                                        Icon(iconData, color: c.primary, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          a.label,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: c.textPrimary,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                        if (a.isDefault) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: c.successBg, borderRadius: BorderRadius.circular(20)),
                                            child: Text(
                                              'افتراضي',
                                              style: TextStyle(color: c.success, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: c.textSecondary, size: 20),
                                          onPressed: () => _showAddEditBottomSheet(address: a),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                          onPressed: () => _deleteAddress(a),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  a.shortAddress,
                                  style: TextStyle(fontSize: 14, color: c.textPrimary, fontFamily: 'Cairo'),
                                ),
                                if (a.governorate.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${a.governorate}، ${a.city.isNotEmpty ? a.city : "مصر"}',
                                    style: TextStyle(fontSize: 12, color: c.textSecondary, fontFamily: 'Cairo'),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.layers_outlined, size: 14, color: c.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      'الطابق: ${a.floor ?? "غير محدد"} · مصعد: ${a.hasElevator ? "نعم" : "لا"}',
                                      style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                                if (!a.isDefault) ...[
                                  const Divider(height: 20),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () => _makeDefault(a),
                                      child: Text(
                                        'تعيين كافتراضي',
                                        style: TextStyle(fontFamily: 'Cairo', color: c.primary, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: c.primary,
        onPressed: () => _showAddEditBottomSheet(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    ),
  );
}
}

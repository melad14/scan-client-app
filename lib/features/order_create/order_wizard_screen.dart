import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/service.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:patient_app/core/theme/app_colors.dart';

class OrderWizardScreen extends StatefulWidget {
  final String category;

  const OrderWizardScreen({super.key, required this.category});

  @override
  State<OrderWizardScreen> createState() => _OrderWizardScreenState();
}

class _OrderWizardScreenState extends State<OrderWizardScreen> {
  int _currentStep = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Services catalog
  List<MedicalService> _servicesCatalog = [];
  final List<String> _selectedServiceIds = [];

  // Patient Info
  final _patientNameController = TextEditingController();
  final _patientPhoneController = TextEditingController();
  final _patientAgeController = TextEditingController();
  String _patientGender = 'male';

  // Case Details
  bool _isBedridden = false;
  bool _canMove = true;
  String _locationType = 'home';
  final _weightController = TextEditingController();
  final _floorController = TextEditingController();
  bool _hasElevator = false;
  final _notesController = TextEditingController();

  // Location details
  final _governorateController = TextEditingController(text: 'القاهرة');
  final _districtController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  
  // Detailed Location info
  final _houseNumberController = TextEditingController();
  final _roadController = TextEditingController();
  final _neighbourhoodController = TextEditingController();
  final _suburbController = TextEditingController();
  final _cityController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _countryController = TextEditingController();
  String _countryCode = 'eg';

  // Map and Location Picker State
  LatLng _selectedLatLng = const LatLng(30.0444, 31.2357);
  final MapController _mapController = MapController();
  bool _isFetchingLocation = false;

  // Timing
  String _scheduleDate = 'today'; // today, tomorrow
  String _timeSlot = 'afternoon_12_3'; // morning_9_12, afternoon_12_3, evening_3_6
  bool _isEmergency = false;

  // Pricing calculations
  double _servicesTotal = 0.0;
  double _transferFee = 100.0;
  double _emergencyFee = 0.0;
  double _grandTotal = 0.0;

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    try {
      final endpoint = widget.category == 'xray' ? '/services/xray' : '/services/lab';
      final res = await _api.dio.get(endpoint);
      if (res.statusCode == 200) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _servicesCatalog = list.map((item) => MedicalService.fromJson(item)).toList();
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'فشل تحميل قائمة الفحوصات الطبية');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculatePriceDetails() {
    double servicesSum = 0.0;
    for (var id in _selectedServiceIds) {
      final s = _servicesCatalog.firstWhere((element) => element.id == id);
      servicesSum += s.price;
    }
    
    // Surcharges simulation based on configuration rules
    double transfer = 100.0;
    double emergency = _isEmergency ? 150.0 : 0.0;

    setState(() {
      _servicesTotal = servicesSum;
      _transferFee = transfer;
      _emergencyFee = emergency;
      _grandTotal = _servicesTotal + _transferFee + _emergencyFee;
    });
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    try {
      final response = await _api.dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': latLng.latitude,
          'lon': latLng.longitude,
          'accept-language': 'ar',
        },
        options: Options(
          headers: {
            'User-Agent': 'ScanGoApp/1.0',
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final address = response.data['address'];
        
        // Print the geocoding API output to the debug console
        debugPrint('=== Nominatim Reverse Geocode Result ===');
        debugPrint(response.data.toString());
        debugPrint('=======================================');

        if (address != null) {
          final String houseNumber = address['house_number'] ?? '';
          final String road = address['road'] ?? address['street'] ?? '';
          final String neighbourhood = address['neighbourhood'] ?? '';
          final String suburb = address['suburb'] ?? address['quarter'] ?? '';
          final String city = address['city'] ?? address['town'] ?? '';
          final String state = address['state'] ?? address['governorate'] ?? 'القاهرة';
          final String postcode = address['postcode'] ?? '';
          final String country = address['country'] ?? 'مصر';
          final String countryCode = address['country_code'] ?? 'eg';

          // Improve district accuracy: check suburb -> neighbourhood -> quarter -> town -> city
          String district = address['suburb'] ?? address['neighbourhood'] ?? address['quarter'] ?? address['city_district'] ?? address['town'] ?? address['city'] ?? '';
          district = district.replaceAll('قسم ', '').trim();
          if (district.isEmpty) district = 'القاهرة';

          String governorate = state.replaceAll('محافظة ', '').trim();

          String street = road;
          if (street.isEmpty) {
            street = address['amenity'] ?? address['shop'] ?? address['tourism'] ?? '';
          }
          final fullStreet = street + (houseNumber.isNotEmpty ? ' $houseNumber' : '');
          
          setState(() {
            _houseNumberController.text = houseNumber;
            _roadController.text = road;
            _neighbourhoodController.text = neighbourhood;
            _suburbController.text = suburb;
            _cityController.text = city;
            _governorateController.text = governorate;
            _postcodeController.text = postcode;
            _countryController.text = country;
            _countryCode = countryCode;

            // Keep legacy inputs populated for compatibility
            _districtController.text = district;
            if (fullStreet.isNotEmpty) {
              _streetController.text = fullStreet;
            }
          });
        }
      }
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _errorMessage = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = 'يرجى تفعيل خدمة تحديد الموقع (GPS) في الهاتف.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _errorMessage = 'تم رفض إذن الوصول للموقع الجغرافي.');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() => _errorMessage = 'إذن الموقع مرفوض نهائياً. يرجى تفعيله من إعدادات الهاتف.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLatLng = newLatLng;
      });
      _mapController.move(newLatLng, 15.0);
      _reverseGeocode(newLatLng); // Trigger reverse geocoding
    } catch (e) {
      setState(() => _errorMessage = 'تعذر الحصول على موقعك الحالي.');
    } finally {
      setState(() {
        _isFetchingLocation = false;
      });
    }
  }

  Future<void> _submitOrder() async {
    setState(() => _isLoading = true);
    try {
      final date = _scheduleDate == 'today'
          ? DateTime.now()
          : DateTime.now().add(const Duration(days: 1));

      final payload = {
        'serviceCategory': widget.category,
        'serviceIds': _selectedServiceIds,
        'patientName': _patientNameController.text.trim(),
        'patientPhone': _patientPhoneController.text.trim(),
        'patientAge': int.tryParse(_patientAgeController.text.trim()),
        'patientGender': _patientGender,
        'caseDetails': {
          'isBedridden': _isBedridden,
          'canMove': _canMove,
          'locationType': _locationType,
          'weight': double.tryParse(_weightController.text.trim()),
          'floor': int.tryParse(_floorController.text.trim()),
          'hasElevator': _hasElevator,
          'notes': _notesController.text.trim(),
        },
        'location': {
          'governorate': _governorateController.text.trim(),
          'district': _districtController.text.trim(),
          'street': _streetController.text.trim(),
          'building': _buildingController.text.trim(),
          'houseNumber': _houseNumberController.text.trim(),
          'road': _roadController.text.trim(),
          'neighbourhood': _neighbourhoodController.text.trim(),
          'suburb': _suburbController.text.trim(),
          'city': _cityController.text.trim(),
          'postcode': _postcodeController.text.trim(),
          'country': _countryController.text.trim(),
          'countryCode': _countryCode,
          'coordinates': [_selectedLatLng.longitude, _selectedLatLng.latitude] // dynamic coordinates
        },
        'schedule': {
          'date': date.toIso8601String(),
          'timeSlot': _timeSlot,
          'isEmergency': _isEmergency
        },
        'paymentMethod': 'cash'
      };

      final res = await _api.dio.post(Constants.orders, data: payload);
      if (res.statusCode == 201) {
        final orderId = res.data['data']['_id'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الطلب وإرساله للإدارة بنجاح!')),
        );
        // Redirect to detail timeline tracking
        context.go('/orders/$orderId');
      }
    } catch (e) {
      setState(() => _errorMessage = 'فشل تسجيل الطلب. يرجى مراجعة البيانات المدخلة.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 1 && _selectedServiceIds.isEmpty) {
      setState(() => _errorMessage = 'يرجى تحديد خدمة واحدة على الأقل');
      return;
    }
    
    if (_currentStep == 2) {
      if (_patientNameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'يرجى إدخال اسم المريض بالكامل');
        return;
      }
      if (_patientPhoneController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'يرجى إدخال رقم هاتف المريض للتواصل');
        return;
      }
      if (_patientAgeController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'يرجى إدخال عمر المريض');
        return;
      }
    }
    
    if (_currentStep == 4) {
      if (_weightController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'يرجى إدخال الوزن التقريبي للمريض');
        return;
      }
    }
    
    if (_currentStep == 5) {
      if (_governorateController.text.trim().isEmpty ||
          _districtController.text.trim().isEmpty ||
          _streetController.text.trim().isEmpty ||
          _buildingController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'يرجى إدخال تفاصيل العنوان كاملة (المحافظة، الحي، الشارع، الطابق/الشقة)');
        return;
      }
    }
    
    setState(() {
      _errorMessage = null;
      if (_currentStep < 9) {
        _currentStep++;
        if (_currentStep == 7) _calculatePriceDetails();
      }
    });
  }

  void _prevStep() {
    setState(() {
      _errorMessage = null;
      if (_currentStep > 1) _currentStep--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('خطوة $_currentStep من 9: حجز خدمة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step indicator bar
                  LinearProgressIndicator(value: _currentStep / 9.0),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Step View Router
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildStepView(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Wizard Nav actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 1)
                        ElevatedButton(
                          onPressed: _prevStep,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(120, 52),
                          ),
                          child: const Text('السابق'),
                        )
                      else
                        const SizedBox(),
                      
                      ElevatedButton(
                        onPressed: _currentStep == 9 ? _submitOrder : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(120, 52),
                        ),
                        child: Text(_currentStep == 9 ? 'تأكيد وحجز الزيارة' : 'التالي'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStepView() {
    switch (_currentStep) {
      case 1: return _buildStep1SelectServices();
      case 2: return _buildStep2PatientDetails();
      case 3: return _buildStep3PrescriptionPhoto();
      case 4: return _buildStep4CaseDetails();
      case 5: return _buildStep5LocationSelector();
      case 6: return _buildStep6TimingSlot();
      case 7: return _buildStep7PricingSummary();
      case 8: return _buildStep8PaymentChoice();
      case 9: return _buildStep9VerificationConfirm();
      default: return const SizedBox();
    }
  }

  Widget _buildStep1SelectServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الخطوة 1: اختر الفحوصات المطلوبة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._servicesCatalog.map((service) {
          final isChecked = _selectedServiceIds.contains(service.id);
          return CheckboxListTile(
            title: Text(service.nameAr),
            subtitle: Text('${service.price} ج.م - ${service.description}'),
            value: isChecked,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedServiceIds.add(service.id);
                } else {
                  _selectedServiceIds.remove(service.id);
                }
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildStep2PatientDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الخطوة 2: بيانات المريض', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _patientNameController,
          decoration: const InputDecoration(labelText: 'اسم المريض بالكامل *'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _patientPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم هاتف المريض للتواصل *'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _patientAgeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'عمر المريض *'),
        ),
        const SizedBox(height: 16),
        const Text('الجنس:'),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('ذكر'),
                value: 'male',
                groupValue: _patientGender,
                onChanged: (val) => setState(() => _patientGender = val!),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('أنثى'),
                value: 'female',
                groupValue: _patientGender,
                onChanged: (val) => setState(() => _patientGender = val!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3PrescriptionPhoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الخطوة 3: صورة الروشتة (اختياري)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('إرفاق صورة الروشتة يساعد الفني في مراجعة وتجهيز المستلزمات الطبية المطلوبة قبل الزيارة.'),
        const SizedBox(height: 32),
        Center(
          child: InkWell(
            onTap: () {
              // Simulate uploading prescription photo
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم محاكاة إرفاق صورة الروشتة بنجاح')),
              );
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 48, color: Color(0xFF0D9488)),
                  SizedBox(height: 12),
                  Text('اضغط لالتقاط أو اختيار صورة الروشتة', style: TextStyle(fontSize: 11), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep4CaseDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الخطوة 4: طبيعة الحالة الطبية للتحضير', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('المريض ملازم للفراش (Bedridden)'),
          subtitle: const Text('فحوصات الأشعة تستدعي تحضيرات خاصة بالسرير للـ Bedridden'),
          value: _isBedridden,
          onChanged: (val) => setState(() => _isBedridden = val),
        ),
        SwitchListTile(
          title: const Text('قادر على الحركة الخفيفة'),
          value: _canMove,
          onChanged: (val) => setState(() => _canMove = val),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الوزن التقريبي للمريض (كجم) *'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _floorController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'رقم الطابق السكني'),
        ),
        SwitchListTile(
          title: const Text('يوجد مصعد بناية (Elevator)'),
          value: _hasElevator,
          onChanged: (val) => setState(() => _hasElevator = val),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'ملاحظات وتوجيهات للفني الطبي'),
        ),
      ],
    );
  }

  Widget _buildStep5LocationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الخطوة 5: حدد موقع الزيارة المنزلية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'قم بتحديد موقعك بدقة على الخريطة لتسهيل وصول الفني الطبي إليك، ثم أكمل تفاصيل العنوان بالأسفل.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        
        // Map Container
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLatLng,
                    initialZoom: 14.0,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        _selectedLatLng = latLng;
                      });
                      _reverseGeocode(latLng); // Trigger reverse geocoding
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
                          point: _selectedLatLng,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.red,
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Locate Me Button
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: InkWell(
                    onTap: _isFetchingLocation ? null : _getCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B), // dark purple
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4), width: 1.5),
                      ),
                      child: _isFetchingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF00D4AA), // teal
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.my_location_rounded, color: Color(0xFF00D4AA), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'تحديد موقعي الحالي 📍',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'الإحداثيات المحددة: ${_selectedLatLng.latitude.toStringAsFixed(5)}, ${_selectedLatLng.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Inter'),
          ),
        ),
        const SizedBox(height: 24),
        
        TextField(
          controller: _governorateController,
          decoration: const InputDecoration(labelText: 'المحافظة'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cityController,
          decoration: const InputDecoration(labelText: 'المدينة'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _districtController,
          decoration: const InputDecoration(labelText: 'الحي / المنطقة (مثال: شبرا)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _neighbourhoodController,
          decoration: const InputDecoration(labelText: 'المجاورة / الشياخة (neighbourhood)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _streetController,
          decoration: const InputDecoration(labelText: 'الشارع ورقم البناية (كامل)'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _roadController,
                decoration: const InputDecoration(labelText: 'اسم الشارع / الطريق'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _houseNumberController,
                decoration: const InputDecoration(labelText: 'رقم المبنى / البناية'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _buildingController,
          decoration: const InputDecoration(labelText: 'رقم الطابق أو الشقة بالتفصيل'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _postcodeController,
                decoration: const InputDecoration(labelText: 'الرمز البريدي'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _countryController,
                decoration: const InputDecoration(labelText: 'البلد'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep6TimingSlot() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الخطوة 6: جدول توقيت الزيارة المنزلية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('موعد الزيارة:'),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('اليوم'),
                value: 'today',
                groupValue: _scheduleDate,
                onChanged: (val) => setState(() => _scheduleDate = val!),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('غداً'),
                value: 'tomorrow',
                groupValue: _scheduleDate,
                onChanged: (val) => setState(() => _scheduleDate = val!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('فترة الزيارة المفضلة:'),
        DropdownButtonFormField<String>(
          value: _timeSlot,
          onChanged: (val) => setState(() => _timeSlot = val!),
          items: const [
            DropdownMenuItem(value: 'morning_9_12', child: Text('صباحاً (9:00 - 12:00)')),
            DropdownMenuItem(value: 'afternoon_12_3', child: Text('ظهراً (12:00 - 3:00)')),
            DropdownMenuItem(value: 'evening_3_6', child: Text('مساءً (3:00 - 6:00)')),
          ],
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('حالة طوارئ فحص فوري عاجل'),
          subtitle: const Text('يتم احتساب رسوم إضافية لضمان تحرك فني طوارئ خلال ساعة'),
          value: _isEmergency,
          onChanged: (val) {
            setState(() => _isEmergency = val);
          },
        ),
      ],
    );
  }

  Widget _buildStep7PricingSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الخطوة 7: تفاصيل تسعير الفاتورة للفحص', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildPricingRow('إجمالي رسوم الفحوصات:', '$_servicesTotal ج.م'),
        const SizedBox(height: 12),
        _buildPricingRow('رسوم انتقال الفني للمنزل:', '$_transferFee ج.م'),
        const SizedBox(height: 12),
        _buildPricingRow('رسوم الطوارئ الإضافية:', '$_emergencyFee ج.م'),
        const Divider(height: 32, thickness: 1),
        _buildPricingRow('إجمالي المبلغ المستحق:', '$_grandTotal ج.م', isTotal: true),
      ],
    );
  }

  Widget _buildPricingRow(String title, String value, {bool isTotal = false}) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? c.textPrimary : c.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? c.success : c.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStep8PaymentChoice() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الخطوة 8: طريقة الدفع والتسوية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListTile(
          leading: Icon(Icons.money, color: Colors.green),
          title: Text('الدفع نقداً للفني الطبي بعد الزيارة (Cash)'),
          subtitle: Text('الدفع كاش هو الخيار المتاح حالياً في المرحلة الأولى للمشروع. وسائل الدفع الإلكتروني تضاف قريباً.'),
          selected: true,
        ),
      ],
    );
  }

  Widget _buildStep9VerificationConfirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الخطوة 9: مراجعة نهائية للطلب قبل التأكيد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.healing_outlined),
          title: const Text('الخدمات المحددة:'),
          subtitle: Text(
            _servicesCatalog
                .where((s) => _selectedServiceIds.contains(s.id))
                .map((s) => s.nameAr)
                .join(', '),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.person_pin),
          title: const Text('اسم المريض للتواصل:'),
          subtitle: Text(_patientNameController.text),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('عنوان الزيارة:'),
          subtitle: Text(
            '${_streetController.text}، ${_districtController.text}، ${_governorateController.text}',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.alarm),
          title: const Text('الموعد:'),
          subtitle: Text(
            '${_scheduleDate == 'today' ? 'اليوم' : 'غداً'} فترة ${_timeSlot == 'morning_9_12' ? 'صباحاً' : 'ظهراً'}',
          ),
        ),
        const Divider(height: 32),
        Text(
          'قيمة الفاتورة النهائية: $_grandTotal ج.م',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.success),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientPhoneController.dispose();
    _patientAgeController.dispose();
    _weightController.dispose();
    _floorController.dispose();
    _notesController.dispose();
    _governorateController.dispose();
    _districtController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _houseNumberController.dispose();
    _roadController.dispose();
    _neighbourhoodController.dispose();
    _suburbController.dispose();
    _cityController.dispose();
    _postcodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }
}

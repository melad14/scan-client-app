import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/service.dart';
import 'package:patient_app/core/models/saved_patient.dart';
import 'package:patient_app/core/models/saved_address.dart';
import 'package:patient_app/core/models/category.dart';
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
  ServiceCategory? _categoryMeta;

  // Services catalog
  List<MedicalService> _servicesCatalog = [];
  final List<String> _selectedServiceIds = [];

  // Saved Patients & Addresses lists
  List<SavedPatient> _savedPatientsList = [];
  List<SavedAddress> _savedAddressesList = [];

  // Selections
  SavedPatient? _selectedPatient;
  SavedAddress? _selectedAddress;

  // Temporary overrides for manual or conditional case details
  bool _isBedridden = false;
  bool _canMove = true;
  final _weightController = TextEditingController();
  final _floorController = TextEditingController();
  bool _hasElevator = false;
  final _notesController = TextEditingController();

  // Simulated prescription upload state
  bool _hasPrescription = false;
  String? _prescriptionFilename;
  bool _instructionsConfirmed = false;

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
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch services catalog
      final catalogEndpoint = '/services/category/${widget.category}';
      final catalogRes = await _api.dio.get(catalogEndpoint);
      
      // 2. Fetch saved patients
      final patientsRes = await _api.dio.get(Constants.savedPatients);
      
      // 3. Fetch saved addresses
      final addressesRes = await _api.dio.get(Constants.savedAddresses);

      // 4. Fetch categories list dynamically to extract meta
      ServiceCategory? matchedCategory;
      try {
        final categoriesRes = await _api.dio.get(Constants.categories);
        final List catList = categoriesRes.data['data'] ?? [];
        final parsedCats = catList.map((item) => ServiceCategory.fromJson(item)).toList();
        matchedCategory = parsedCats.firstWhere(
          (c) => c.key == widget.category,
          orElse: () => ServiceCategory(
            id: '',
            nameAr: widget.category == 'xray' ? 'أشعة سينية' : (widget.category == 'lab' ? 'تحاليل طبية' : widget.category),
            nameEn: widget.category,
            key: widget.category,
            icon: 'category',
            iconBg: '#E6F0FA',
            iconColor: '#2B7EC2',
            sortOrder: 0,
            isActive: true,
          ),
        );
      } catch (catErr) {
        debugPrint('Error getting category metadata dynamically: $catErr');
      }

      if (mounted) {
        final List serviceList = catalogRes.data['data'] ?? [];
        final List patientList = patientsRes.data['data'] ?? [];
        final List addressList = addressesRes.data['data'] ?? [];

        setState(() {
          _categoryMeta = matchedCategory;
          _servicesCatalog = serviceList.map((item) => MedicalService.fromJson(item)).toList();
          _savedPatientsList = patientList.map((item) => SavedPatient.fromJson(item)).toList();
          _savedAddressesList = addressList.map((item) => SavedAddress.fromJson(item)).toList();

          // Auto-select default patient
          if (_savedPatientsList.isNotEmpty) {
            _selectedPatient = _savedPatientsList.firstWhere(
              (p) => p.isDefault,
              orElse: () => _savedPatientsList.first,
            );
            _applyPatientDefaults(_selectedPatient!);
          }

          // Auto-select default address
          if (_savedAddressesList.isNotEmpty) {
            _selectedAddress = _savedAddressesList.firstWhere(
              (a) => a.isDefault,
              orElse: () => _savedAddressesList.first,
            );
            _applyAddressDefaults(_selectedAddress!);
          }
        });
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint('DioException details: path=${e.requestOptions.path}, status=${e.response?.statusCode}, data=${e.response?.data}');
      } else {
        debugPrint('Error fetching initial booking data: $e');
      }
      setState(() => _errorMessage = 'فشل تحميل بيانات الحجز الأساسية');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Timing state variables
  DateTime _customScheduleDate = DateTime.now();

  void _applyPatientDefaults(SavedPatient p) {
    setState(() {
      _isBedridden = p.caseDefaults?['isBedridden'] ?? false;
      _canMove = p.caseDefaults?['canMove'] ?? true;
      if (p.caseDefaults?['weight'] != null) {
        _weightController.text = p.caseDefaults!['weight'].toString();
      } else {
        _weightController.clear();
      }
      _notesController.text = p.caseDefaults?['notes'] ?? '';
    });
  }

  void _applyAddressDefaults(SavedAddress a) {
    setState(() {
      if (a.floor != null) {
        _floorController.text = a.floor.toString();
      } else {
        _floorController.clear();
      }
      _hasElevator = a.hasElevator;
    });
  }

  void _calculatePriceDetails() {
    double servicesSum = 0.0;
    if (widget.category != 'prescription_only') {
      for (var id in _selectedServiceIds) {
        final s = _servicesCatalog.firstWhere((element) => element.id == id);
        servicesSum += s.price;
      }
    }
    
    // Simulate pricing parameters
    double transfer = 150.0;
    double emergency = _isEmergency ? 150.0 : 0.0;

    setState(() {
      _servicesTotal = servicesSum;
      _transferFee = transfer;
      _emergencyFee = emergency;
      _grandTotal = _servicesTotal + _transferFee + _emergencyFee;
    });
  }

  Future<void> _submitOrder() async {
    if (_selectedPatient == null || _selectedAddress == null) {
      setState(() => _errorMessage = 'يرجى اختيار المريض وموقع الزيارة');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final DateTime date;
      if (_scheduleDate == 'today') {
        date = DateTime.now();
      } else if (_scheduleDate == 'tomorrow') {
        date = DateTime.now().add(const Duration(days: 1));
      } else {
        date = _customScheduleDate;
      }

      final payload = {
        'serviceCategory': widget.category,
        'serviceIds': _selectedServiceIds,
        'prescription': {
          'images': _hasPrescription && _prescriptionFilename != null ? [_prescriptionFilename!] : [],
          'pdf': null
        },
        'patientName': _selectedPatient!.name,
        'patientPhone': _selectedPatient!.phone,
        'patientAge': _selectedPatient!.age,
        'patientGender': _selectedPatient!.gender,
        'caseDetails': {
          'isBedridden': _isBedridden,
          'canMove': _canMove,
          'locationType': 'home',
          'weight': double.tryParse(_weightController.text.trim()),
          'floor': int.tryParse(_floorController.text.trim()),
          'hasElevator': _hasElevator,
          'notes': _notesController.text.trim(),
        },
        'location': {
          'governorate': _selectedAddress!.governorate,
          'district': _selectedAddress!.district,
          'street': _selectedAddress!.street,
          'building': _selectedAddress!.building,
          'houseNumber': _selectedAddress!.houseNumber,
          'road': _selectedAddress!.road,
          'neighbourhood': _selectedAddress!.neighbourhood,
          'suburb': _selectedAddress!.suburb,
          'city': _selectedAddress!.city,
          'postcode': _selectedAddress!.postcode,
          'country': _selectedAddress!.country,
          'countryCode': _selectedAddress!.countryCode,
          'coordinates': [_selectedAddress!.lng ?? 31.2357, _selectedAddress!.lat ?? 30.0444]
        },
        'schedule': {
          'date': date.toIso8601String(),
          'timeSlot': _timeSlot,
          'isEmergency': _isEmergency
        },
        'paymentMethod': 'cash',
        'instructionsAcknowledged': _instructionsConfirmed
      };

      final res = await _api.dio.post(Constants.orders, data: payload);
      if (res.statusCode == 201) {
        final orderId = res.data['data']['_id'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الطلب وإرساله للإدارة بنجاح!')),
        );
        context.go('/orders/$orderId?fromWizard=true');
      }
    } catch (e) {
      String msg = 'فشل تسجيل الطلب. يرجى المحاولة مرة أخرى.';
      if (e is DioException) {
        final serverMsg = e.response?.data?['message'];
        if (serverMsg != null && serverMsg.toString().isNotEmpty) {
          msg = serverMsg.toString();
        }
        debugPrint('Order submit error: path=${e.requestOptions.path}, status=${e.response?.statusCode}, data=${e.response?.data}');
      }
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInstructionsBottomSheet(BuildContext context, List<MedicalService> services) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.warning, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'تعليمات طبية هامة قبل إجراء الفحص',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: c.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'يرجى تأكيد التزامك بالتحضيرات الطبية لضمان دقة التحليل وتجنب إلغاء الزيارة المنزلية:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: services.map((s) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.borderLight.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.nameAr,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.instructionsAr,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: c.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  setState(() {
                    _instructionsConfirmed = true;
                  });
                  Navigator.pop(context);
                  _nextStep();
                },
                child: const Text(
                  'أؤكد قراءة التعليمات والالتزام بها',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _nextStep() {
    setState(() => _errorMessage = null);

    if (_currentStep == 1) {
      if (_selectedPatient == null) {
        setState(() => _errorMessage = 'يرجى تحديد مريض لتنفيذ الفحص له');
        return;
      }
      if (_selectedAddress == null) {
        setState(() => _errorMessage = 'يرجى تحديد عنوان الزيارة المنزلية');
        return;
      }
      if (widget.category == 'xray' && _weightController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'يرجى إدخال الوزن التقريبي للمريض لتجهيز معدات الأشعة');
        return;
      }
    }
    
    if (_currentStep == 2) {
      if (widget.category == 'prescription_only') {
        if (!_hasPrescription) {
          setState(() => _errorMessage = 'يرجى إرفاق صورة الروشتة للمتابعة');
          return;
        }
      } else {
        // If catalog has services, require at least one. If empty, allow continuing with prescription.
        if (_servicesCatalog.isNotEmpty && _selectedServiceIds.isEmpty && !_hasPrescription) {
          setState(() => _errorMessage = 'يرجى تحديد خدمة واحدة على الأقل أو إرفاق الروشتة');
          return;
        }

        // Verify medical instructions are confirmed if present
        final selectedServices = _servicesCatalog.where((s) => _selectedServiceIds.contains(s.id)).toList();
        final servicesWithInstructions = selectedServices.where((s) => s.instructionsAr.isNotEmpty).toList();
        if (servicesWithInstructions.isNotEmpty && !_instructionsConfirmed) {
          _showInstructionsBottomSheet(context, servicesWithInstructions);
          return;
        }
      }
    }
    
    setState(() {
      if (_currentStep < 4) {
        _currentStep++;
        if (_currentStep == 4) {
          _calculatePriceDetails();
        }
      }
    });
  }

  void _prevStep() {
    setState(() {
      _errorMessage = null;
      if (_currentStep > 1) _currentStep--;
    });
  }

  void _showAddPatientSheet() {
    final c = context.colors;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final ageController = TextEditingController();
    String gender = 'male';
    String relationship = 'spouse';

    showModalBottomSheet(
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
                    Text('إضافة مريض جديد للفحص', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'اسم المريض بالكامل *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'رقم الهاتف للتواصل *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'العمر *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: relationship,
                      decoration: const InputDecoration(labelText: 'صلة القرابة *'),
                      items: const [
                        DropdownMenuItem(value: 'spouse', child: Text('الزوج / الزوجة')),
                        DropdownMenuItem(value: 'parent', child: Text('الأب / الأم')),
                        DropdownMenuItem(value: 'child', child: Text('الابن / الابنة')),
                        DropdownMenuItem(value: 'sibling', child: Text('الأخ / الأخت')),
                        DropdownMenuItem(value: 'other', child: Text('قريب / آخر')),
                      ],
                      onChanged: (val) => setModalState(() => relationship = val!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('ذكر'),
                            value: 'male',
                            groupValue: gender,
                            activeColor: c.primary,
                            onChanged: (val) => setModalState(() => gender = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('أنثى'),
                            value: 'female',
                            groupValue: gender,
                            activeColor: c.primary,
                            onChanged: (val) => setModalState(() => gender = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: c.primary, foregroundColor: Colors.white),
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty ||
                            ageController.text.trim().isEmpty) {
                          return;
                        }
                        
                        Navigator.pop(context);
                        setState(() => _isLoading = true);
                        try {
                          final payload = {
                            'label': nameController.text.trim().split(' ').first,
                            'name': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'age': int.parse(ageController.text.trim()),
                            'gender': gender,
                            'relationship': relationship
                          };
                          final res = await _api.dio.post(Constants.savedPatients, data: payload);
                          if (res.statusCode == 201) {
                            final newPatient = SavedPatient.fromJson(res.data['data']);
                            final patientsRes = await _api.dio.get(Constants.savedPatients);
                            final List patientList = patientsRes.data['data'] ?? [];
                            
                            setState(() {
                              _savedPatientsList = patientList.map((item) => SavedPatient.fromJson(item)).toList();
                              _selectedPatient = _savedPatientsList.firstWhere((p) => p.id == newPatient.id, orElse: () => newPatient);
                              _applyPatientDefaults(_selectedPatient!);
                            });
                          }
                        } catch (_) {}
                        setState(() => _isLoading = false);
                      },
                      child: const Text('إضافة المريض'),
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

  void _showAddAddressSheet() {
    final c = context.colors;
    final labelController = TextEditingController();
    final districtController = TextEditingController();
    final streetController = TextEditingController();
    final buildingController = TextEditingController();
    final floorController = TextEditingController();
    bool hasElevator = false;

    LatLng mapLatLng = const LatLng(30.0444, 31.2357);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            Future<void> detectLocation() async {
              try {
                bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) {
                  await Geolocator.openLocationSettings();
                  return;
                }

                LocationPermission permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                  if (permission == LocationPermission.denied) return;
                }

                if (permission == LocationPermission.deniedForever) {
                  return;
                }

                final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                setModalState(() {
                  mapLatLng = LatLng(position.latitude, position.longitude);
                });
                
                final response = await _api.dio.get(
                  'https://nominatim.openstreetmap.org/reverse',
                  queryParameters: {
                    'format': 'json',
                    'lat': mapLatLng.latitude,
                    'lon': mapLatLng.longitude,
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
                      String detectedDistrict = addr['city_district'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? '';
                      detectedDistrict = detectedDistrict.replaceAll('قسم ', '').trim();
                      districtController.text = detectedDistrict;
                      streetController.text = addr['road'] ?? addr['street'] ?? '';
                    });
                  }
                }
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
                    Text('إضافة عنوان زيارة جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 160,
                        child: Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: mapLatLng,
                                initialZoom: 14.0,
                                onTap: (pos, latLng) {
                                  setModalState(() => mapLatLng = latLng);
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.patient_app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(point: mapLatLng, child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 36)),
                                  ],
                                ),
                              ],
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: GestureDetector(
                                onTap: detectLocation,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: c.primaryDeep, borderRadius: BorderRadius.circular(20)),
                                  child: const Text('تحديد موقعي', style: TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(labelText: 'تسمية العنوان (البيت، الشغل...) *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: districtController,
                      decoration: const InputDecoration(labelText: 'المنطقة / الحي *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: streetController,
                      decoration: const InputDecoration(labelText: 'الشارع والبناية بالتفصيل *'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: buildingController,
                            decoration: const InputDecoration(labelText: 'رقم الشقة'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: floorController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'الطابق'),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('يوجد مصعد'),
                      value: hasElevator,
                      activeColor: c.primary,
                      onChanged: (val) => setModalState(() => hasElevator = val),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: c.primary, foregroundColor: Colors.white),
                      onPressed: () async {
                        if (labelController.text.trim().isEmpty ||
                            districtController.text.trim().isEmpty ||
                            streetController.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(context);
                        setState(() => _isLoading = true);
                        try {
                          final payload = {
                            'label': labelController.text.trim(),
                            'district': districtController.text.trim(),
                            'street': streetController.text.trim(),
                            'building': buildingController.text.trim(),
                            'floor': int.tryParse(floorController.text.trim()),
                            'hasElevator': hasElevator,
                            'coordinates': [mapLatLng.longitude, mapLatLng.latitude]
                          };
                          final res = await _api.dio.post(Constants.savedAddresses, data: payload);
                          if (res.statusCode == 201) {
                            final newAddress = SavedAddress.fromJson(res.data['data']);
                            final addressesRes = await _api.dio.get(Constants.savedAddresses);
                            final List addressList = addressesRes.data['data'] ?? [];
                            
                            setState(() {
                              _savedAddressesList = addressList.map((item) => SavedAddress.fromJson(item)).toList();
                              _selectedAddress = _savedAddressesList.firstWhere((a) => a.id == newAddress.id, orElse: () => newAddress);
                              _applyAddressDefaults(_selectedAddress!);
                            });
                          }
                        } catch (_) {}
                        setState(() => _isLoading = false);
                      },
                      child: const Text('إضافة العنوان'),
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentStep > 1) {
          _prevStep();
        } else {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/');
          }
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          title: Text(
            'خطوة $_currentStep من 4: حجز ${_getCategoryName()}',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: c.textPrimary),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: c.textPrimary, size: 20),
            onPressed: () {
              if (_currentStep > 1) {
                _prevStep();
              } else {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/');
                }
              }
            },
          ),
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step indicator bar
                  LinearProgressIndicator(
                    value: _currentStep / 4.0,
                    color: c.primary,
                    backgroundColor: c.borderLight,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.errorBg,
                        border: Border.all(color: c.error.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: c.error, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Render correct step view
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: _buildStepView(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // Bottom actions bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 1)
                        OutlinedButton(
                          onPressed: _prevStep,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: c.border),
                          ),
                          child: Text('السابق', style: TextStyle(fontFamily: 'Cairo', color: c.textPrimary, fontWeight: FontWeight.bold)),
                        )
                      else
                        const SizedBox(),
                      
                      ElevatedButton(
                        onPressed: _currentStep == 4 ? _submitOrder : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(140, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentStep == 4 ? 'تأكيد وحجز الزيارة' : 'التالي',
                              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Icon(_currentStep == 4 ? Icons.check_circle_outline : Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ),
    );
  }

  String _getCategoryName() {
    if (_categoryMeta != null) return _categoryMeta!.nameAr;
    switch (widget.category) {
      case 'xray': return 'أشعة سينية';
      case 'echo': return 'إيكو قلب';
      case 'ecg': return 'رسم قلب';
      case 'lab': return 'تحاليل طبية';
      default: return 'فحوصات طبية';
    }
  }

  String _getNotesTitle() {
    if (_categoryMeta != null) return 'ملاحظات خاصة (${_categoryMeta!.nameAr})';
    switch (widget.category) {
      case 'lab': return 'ملاحظات خاصة (تحاليل)';
      case 'echo': return 'ملاحظات خاصة (إيكو)';
      case 'ecg': return 'ملاحظات خاصة (رسم قلب)';
      default: return 'ملاحظات خاصة بالخدمة';
    }
  }

  String _getNotesPlaceholder() {
    if (_categoryMeta != null) return 'أي ملاحظات خاصة بفحص ${_categoryMeta!.nameAr}...';
    switch (widget.category) {
      case 'lab': return 'هل المريض صائم؟ أو أي ملاحظات للتحاليل...';
      case 'echo': return 'أي ملاحظات خاصة بفحص الإيكو أو حالة المريض...';
      case 'ecg': return 'أي ملاحظات خاصة برسم القلب أو النبض...';
      default: return 'أي تفاصيل أو ملاحظات إضافية للفني الطبي...';
    }
  }

  Widget _buildStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1WhoAndWhere();
      case 2:
        return _buildStep2WhatServices();
      case 3:
        return _buildStep3WhenTiming();
      case 4:
        return _buildStep4ConfirmAndPay();
      default:
        return const SizedBox();
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  STEP 1: WHO & WHERE
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep1WhoAndWhere() {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('من المريض؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
            TextButton.icon(
              onPressed: _showAddPatientSheet,
              icon: Icon(Icons.add, size: 16, color: c.primary),
              label: Text('مريض جديد', style: TextStyle(fontFamily: 'Cairo', color: c.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // Patients horizontal cards
        if (_savedPatientsList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: c.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لا يوجد مرضى محفوظون. اضغط على "+ مريض جديد" للبدء.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _savedPatientsList.length,
              itemBuilder: (context, index) {
                final p = _savedPatientsList[index];
                final isSelected = _selectedPatient?.id == p.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPatient = p;
                      _applyPatientDefaults(p);
                    });
                  },
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(left: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? c.primary : c.borderLight,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                p.label,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? c.primary : c.textPrimary, fontFamily: 'Cairo'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected) Icon(Icons.check_circle, size: 16, color: c.primary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(p.name, style: TextStyle(fontSize: 11, color: c.textSecondary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${p.age} سنة · ${p.gender == 'male' ? 'ذكر' : 'أنثى'}', style: TextStyle(fontSize: 11, color: c.textMuted, fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('أين موقع الزيارة؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
            TextButton.icon(
              onPressed: _showAddAddressSheet,
              icon: Icon(Icons.add, size: 16, color: c.primary),
              label: Text('عنوان جديد', style: TextStyle(fontFamily: 'Cairo', color: c.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Addresses vertical cards
        if (_savedAddressesList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: c.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لا يوجد عناوين محفوظة. اضغط على "+ عنوان جديد" لإضافة عنوان للبدء.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          ..._savedAddressesList.map((a) {
            final isSelected = _selectedAddress?.id == a.id;
            IconData iconData = Icons.home_rounded;
            if (a.icon == 'work') iconData = Icons.work_rounded;
            if (a.icon == 'hospital') iconData = Icons.local_hospital_rounded;
            if (a.icon == 'family') iconData = Icons.family_restroom_rounded;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAddress = a;
                  _applyAddressDefaults(a);
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? c.primary : c.borderLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                      child: Icon(iconData, color: c.primary, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
                          const SizedBox(height: 3),
                          Text(a.shortAddress, style: TextStyle(fontSize: 12, color: c.textSecondary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (isSelected) Icon(Icons.check_circle, color: c.primary, size: 20),
                  ],
                ),
              ),
            );
          }),

        const Divider(height: 32),

        // Case parameters conditional display (only for Portable X-Ray, which needs building details and logistics prep)
        if (widget.category == 'xray') ...[
          Text('تفاصيل الحالة ومعدات النقل للسرير (أشعة فقط)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('المريض ملازم للفراش (Bedridden)', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            subtitle: const Text('لتنبيه الفني لجلب مساند السرير المخصصة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
            value: _isBedridden,
            activeColor: c.primary,
            onChanged: (val) => setState(() => _isBedridden = val),
          ),
          SwitchListTile(
            title: const Text('قادر على الوقوف الخفيف', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            value: _canMove,
            activeColor: c.primary,
            onChanged: (val) => setState(() => _canMove = val),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الوزن التقريبي (كجم) *'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _floorController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'رقم الطابق السكني'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('يوجد مصعد بناية (Elevator)', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            value: _hasElevator,
            activeColor: c.primary,
            onChanged: (val) => setState(() => _hasElevator = val),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظات طبية وتوجيهات خاصة للفني'),
          ),
        ] else ...[
          // For other categories, show dynamic notes
          Text(_getNotesTitle(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(labelText: _getNotesPlaceholder()),
          ),
        ]
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  STEP 2: WHAT (Services Selection + Prescription Photo)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep2WhatServices() {
    final c = context.colors;
    final isPrescriptionOnly = widget.category == 'prescription_only';
    final selectedServices = _servicesCatalog.where((s) => _selectedServiceIds.contains(s.id)).toList();
    final servicesWithInstructions = selectedServices.where((s) => s.instructionsAr.isNotEmpty).toList();
    final hasInstructions = servicesWithInstructions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isPrescriptionOnly) ...[
          Text('اختر الفحوصات الطبية المطلوبة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 12),

          if (_servicesCatalog.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: c.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد فحوصات مضافة لهذه الفئة حتى الآن.\nيمكنك الاستمرار وإرفاق الروشتة ليحدد لك المركز الفحوصات المناسبة.',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: c.textPrimary, height: 1.6),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._servicesCatalog.map((service) {
              final isChecked = _selectedServiceIds.contains(service.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isChecked ? c.primary : c.borderLight),
                ),
                child: CheckboxListTile(
                  title: Text(service.nameAr, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${service.price} ج.م · ${service.description ?? ""}', style: TextStyle(fontFamily: 'Cairo', color: c.textSecondary, fontSize: 12)),
                  value: isChecked,
                  activeColor: c.primary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedServiceIds.add(service.id);
                      } else {
                        _selectedServiceIds.remove(service.id);
                      }
                      // Reset acknowledgment if services list changes
                      _instructionsConfirmed = false;
                    });
                  },
                ),
              );
            }),
          const Divider(height: 36),
        ],


        Text(
          isPrescriptionOnly ? 'إرفاق صورة الروشتة الطبية (إلزامي) ⚠️' : 'إرفاق صورة الروشتة (اختياري)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 8),
        Text(
          isPrescriptionOnly
              ? 'يرجى تصوير الروشتة بشكل واضح ليتمكن فريق المركز من تحديد الفحوصات اللازمة والتكلفة وتأكيد حجزك.'
              : 'تساعد صورة الروشتة الطبية فريق المركز على جلب المستلزمات الطبية الصحيحة والتجهيز الطبي المسبق للحالة.',
          style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Cairo', height: 1.5),
        ),
        const SizedBox(height: 16),
        
        Center(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _hasPrescription = true;
                _prescriptionFilename = 'prescription_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.jpg';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم إرفاق الملف $_prescriptionFilename بنجاح!')),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _hasPrescription ? c.primary : c.border, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _hasPrescription ? Icons.file_present_rounded : Icons.camera_alt_outlined,
                    size: 40,
                    color: _hasPrescription ? c.primary : c.textSecondary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _hasPrescription ? _prescriptionFilename! : 'اضغط لالتقاط أو إرفاق صورة الروشتة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: _hasPrescription ? c.primary : c.textSecondary, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (_hasPrescription) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _hasPrescription = false;
                          _prescriptionFilename = null;
                        });
                      },
                      child: const Text('حذف وإعادة إرفاق', style: TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'Cairo')),
                    )
                  ]
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  STEP 3: WHEN (Timing and Date Selection)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep3WhenTiming() {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('متى ترغب في زيارة فريق المركز؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _scheduleDate = 'today'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _scheduleDate == 'today' ? c.primaryLight : c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _scheduleDate == 'today' ? c.primary : c.borderLight, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: _scheduleDate == 'today' ? c.primary : c.textSecondary),
                      const SizedBox(height: 8),
                      Text('زيارة اليوم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11, color: _scheduleDate == 'today' ? c.primary : c.textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _scheduleDate = 'tomorrow'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _scheduleDate == 'tomorrow' ? c.primaryLight : c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _scheduleDate == 'tomorrow' ? c.primary : c.borderLight, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_repeat_rounded, color: _scheduleDate == 'tomorrow' ? c.primary : c.textSecondary),
                      const SizedBox(height: 8),
                      Text('زيارة غداً', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11, color: _scheduleDate == 'tomorrow' ? c.primary : c.textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 14)),
                  );
                  if (picked != null) {
                    setState(() {
                      _customScheduleDate = picked;
                      _scheduleDate = 'custom';
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _scheduleDate == 'custom' ? c.primaryLight : c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _scheduleDate == 'custom' ? c.primary : c.borderLight, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.calendar_month_rounded, color: _scheduleDate == 'custom' ? c.primary : c.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        _scheduleDate == 'custom'
                            ? '${_customScheduleDate.year}-${_customScheduleDate.month.toString().padLeft(2, '0')}-${_customScheduleDate.day.toString().padLeft(2, '0')}'
                            : 'تاريخ مخصص',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11, color: _scheduleDate == 'custom' ? c.primary : c.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        
        Text('اختر الفترة المفضلة للزيارة:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),

        // Visual selectors for time slots
        _buildTimeSlotCard('morning_9_12', 'الفترة الصباحية', 'من 9:00 ص إلى 12:00 م', Icons.wb_sunny_outlined),
        _buildTimeSlotCard('afternoon_12_3', 'فترة الظهيرة', 'من 12:00 م إلى 3:00 م', Icons.wb_cloudy_outlined),
        _buildTimeSlotCard('evening_3_6', 'الفترة المسائية', 'من 3:00 م إلى 6:00 م', Icons.nights_stay_outlined),

        const Divider(height: 36),

        // Emergency surcharge toggle
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isEmergency ? c.warningBg.withOpacity(0.08) : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _isEmergency ? c.warning : c.borderLight),
          ),
          child: SwitchListTile(
            title: Row(
              children: [
                Icon(Icons.bolt, color: _isEmergency ? c.warning : c.textSecondary),
                const SizedBox(width: 8),
                const Text('زيارة طوارئ عاجلة جداً ⚡', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            subtitle: const Text(
              'سعر الخدمة يزداد بمقدار 150 ج.م، ويتم توجيه أقرب فني إليك فوراً في غضون ساعة.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
            ),
            value: _isEmergency,
            activeColor: c.warning,
            onChanged: (val) {
              setState(() => _isEmergency = val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotCard(String key, String title, String description, IconData icon) {
    final c = context.colors;
    final isSelected = _timeSlot == key;

    return GestureDetector(
      onTap: () => setState(() => _timeSlot = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? c.primaryLight : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? c.primary : c.borderLight, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? c.primary : c.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(fontSize: 11, color: c.textSecondary, fontFamily: 'Cairo')),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: c.primary, size: 18),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  STEP 4: CONFIRMATION & BILLING DETAIL
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep4ConfirmAndPay() {
    final c = context.colors;
    final isPrescriptionOnly = widget.category == 'prescription_only';

    String dateText = '';
    if (_scheduleDate == 'today') {
      dateText = 'اليوم';
    } else if (_scheduleDate == 'tomorrow') {
      dateText = 'غداً';
    } else {
      dateText = '${_customScheduleDate.year}-${_customScheduleDate.month.toString().padLeft(2, '0')}-${_customScheduleDate.day.toString().padLeft(2, '0')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('مراجعة وتأكيد الحجز الطبي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 16),
        
        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borderLight),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                Icons.person_pin,
                'المريض:',
                _selectedPatient?.name ?? 'غير محدد',
                sub: 'العلاقة: ${_selectedPatient != null ? _selectedPatient!.label : ""}',
              ),
              const Divider(height: 20),
              _buildSummaryRow(
                Icons.location_on_outlined,
                'موقع الفحص:',
                _selectedAddress?.shortAddress ?? 'غير محدد',
                sub: _selectedAddress?.label ?? '',
              ),
              const Divider(height: 20),
              _buildSummaryRow(
                Icons.healing_outlined,
                'الفحوصات المطلوبة:',
                isPrescriptionOnly
                    ? 'حجز بواسطة الروشتة المرفقة 📋'
                    : _servicesCatalog
                        .where((s) => _selectedServiceIds.contains(s.id))
                        .map((s) => s.nameAr)
                        .join(', '),
              ),
              const Divider(height: 20),
              _buildSummaryRow(
                Icons.access_time_rounded,
                'موعد الزيارة:',
                '$dateText - ${_timeSlot == 'morning_9_12' ? 'الصباحية' : _timeSlot == 'afternoon_12_3' ? 'الظهر' : 'المسائية'}',
                sub: _isEmergency ? 'زيارة طوارئ عاجلة ⚡' : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        
        Text('تفاصيل الفاتورة الرسمية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borderLight),
          ),
          child: isPrescriptionOnly
              ? Column(
                  children: [
                    _buildPricingRow('تكلفة الفحوصات الطبية المحددة:', 'قيد المراجعة والتسعير'),
                    const SizedBox(height: 8),
                    _buildPricingRow('رسوم انتقال الفريق الطبي للمنزل:', '$_transferFee ج.م'),
                    if (_isEmergency) ...[
                      const SizedBox(height: 8),
                      _buildPricingRow('رسوم خدمة طوارئ إضافية:', '$_emergencyFee ج.م'),
                    ],
                    const Divider(height: 24, thickness: 1),
                    _buildPricingRow('إجمالي رسوم الدفع المستحقة:', 'قيد المراجعة والتسعير', isTotal: true),
                    const SizedBox(height: 12),
                    Text(
                      'ملاحظة: سيقوم فريق المركز بمراجعة الروشتة وتحديد الفحوصات والأسعار بدقة وسنتصل بك هاتفيًا للتأكيد.',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: c.accent, height: 1.5, fontWeight: FontWeight.bold),
                    )
                  ],
                )
              : Column(
                  children: [
                    _buildPricingRow('تكلفة الفحوصات الطبية المحددة:', '$_servicesTotal ج.م'),
                    const SizedBox(height: 8),
                    _buildPricingRow('رسوم انتقال الفريق الطبي للمنزل:', '$_transferFee ج.م'),
                    if (_isEmergency) ...[
                      const SizedBox(height: 8),
                      _buildPricingRow('رسوم خدمة طوارئ إضافية:', '$_emergencyFee ج.م'),
                    ],
                    const Divider(height: 24, thickness: 1),
                    _buildPricingRow('إجمالي رسوم الدفع المستحقة:', '$_grandTotal ج.م', isTotal: true),
                  ],
                ),
        ),

        const SizedBox(height: 24),

        Text('طريقة الدفع والتسوية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.primaryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.payments_outlined, color: c.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الدفع نقداً كاش عند وصول فريق المركز', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.primary, fontFamily: 'Cairo')),
                    Text('الدفع نقداً كاش هو الوسيلة الحالية. سنضيف خيارات فودافون كاش وبطاقات الدفع قريباً.', style: TextStyle(fontSize: 11, color: c.textSecondary, fontFamily: 'Cairo')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String value, {String? sub}) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: c.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: c.textMuted, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 13, color: c.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11, color: c.accent, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
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
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? c.textPrimary : c.textSecondary,
            fontFamily: 'Cairo',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? c.success : c.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _floorController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

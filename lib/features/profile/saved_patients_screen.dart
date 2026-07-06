import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/api/api_client.dart';
import 'package:patient_app/core/models/saved_patient.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/theme/app_colors.dart';
import 'package:dio/dio.dart';

class SavedPatientsScreen extends StatefulWidget {
  const SavedPatientsScreen({super.key});

  @override
  State<SavedPatientsScreen> createState() => _SavedPatientsScreenState();
}

class _SavedPatientsScreenState extends State<SavedPatientsScreen> {
  final _api = ApiClient();
  List<SavedPatient> _patients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.dio.get(Constants.savedPatients);
      if (res.statusCode == 200 && mounted) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _patients = list.map((e) => SavedPatient.fromJson(e)).toList();
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['message'] ?? 'فشل تحميل قائمة المرضى';
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

  String _getRelationshipLabel(String relationship) {
    switch (relationship) {
      case 'self':
        return 'أنا';
      case 'spouse':
        return 'الزوج / الزوجة';
      case 'parent':
        return 'الأب / الأم';
      case 'child':
        return 'الابن / الابنة';
      case 'sibling':
        return 'الأخ / الأخت';
      default:
        return 'قريب / آخر';
    }
  }

  void _showAddEditBottomSheet({SavedPatient? patient}) {
    final c = context.colors;
    final isEdit = patient != null;

    final nameController = TextEditingController(text: patient?.name);
    final phoneController = TextEditingController(text: patient?.phone);
    final ageController = TextEditingController(text: patient?.age?.toString());
    String label = patient?.label ?? '';
    String gender = patient?.gender ?? 'male';
    String relationship = patient?.relationship ?? (isEdit ? 'other' : 'spouse');
    
    // Case defaults variables
    bool isBedridden = patient?.caseDefaults?['isBedridden'] ?? false;
    bool canMove = patient?.caseDefaults?['canMove'] ?? true;
    final weightController = TextEditingController(text: patient?.caseDefaults?['weight']?.toString());
    final notesController = TextEditingController(text: patient?.caseDefaults?['notes']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isEdit ? 'تعديل بيانات مريض' : 'إضافة مريض جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل *',
                        labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary),
                        filled: true,
                        fillColor: c.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف للتواصل *',
                        labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary),
                        filled: true,
                        fillColor: c.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'العمر *',
                        labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary),
                        filled: true,
                        fillColor: c.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('العلاقة / صلة القرابة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Relationship selector (except if relationship is self, which cannot be modified)
                    if (patient?.relationship == 'self')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'صاحب الحساب الأساسي (أنا)',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: c.primary, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: relationship == 'self' ? 'other' : relationship,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: c.surfaceVariant,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'spouse', child: Text('الزوج / الزوجة', style: TextStyle(fontFamily: 'Cairo'))),
                          DropdownMenuItem(value: 'parent', child: Text('الأب / الأم', style: TextStyle(fontFamily: 'Cairo'))),
                          DropdownMenuItem(value: 'child', child: Text('الابن / الابنة', style: TextStyle(fontFamily: 'Cairo'))),
                          DropdownMenuItem(value: 'sibling', child: Text('الأخ / الأخت', style: TextStyle(fontFamily: 'Cairo'))),
                          DropdownMenuItem(value: 'other', child: Text('قريب / آخر', style: TextStyle(fontFamily: 'Cairo'))),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            relationship = val!;
                            if (label.isEmpty) {
                              if (relationship == 'spouse') label = 'الزوج';
                              if (relationship == 'parent') label = 'الأب/الأم';
                              if (relationship == 'child') label = 'الابن';
                              if (relationship == 'sibling') label = 'الأخ';
                              if (relationship == 'other') label = 'قريب';
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (val) => label = val,
                      controller: TextEditingController(text: label),
                      decoration: InputDecoration(
                        labelText: 'تسمية سريعة (مثل: أمي، زوجتي، ابني) *',
                        labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary),
                        filled: true,
                        fillColor: c.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('الجنس:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('ذكر', style: TextStyle(fontFamily: 'Cairo')),
                            value: 'male',
                            groupValue: gender,
                            activeColor: c.primary,
                            onChanged: (val) => setModalState(() => gender = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('أنثى', style: TextStyle(fontFamily: 'Cairo')),
                            value: 'female',
                            groupValue: gender,
                            activeColor: c.primary,
                            onChanged: (val) => setModalState(() => gender = val!),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('طبيعة الحالة الطبية (افتراضية):', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.bold)),
                    SwitchListTile(
                      title: const Text('ملازم للفراش (Bedridden)', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                      value: isBedridden,
                      activeColor: c.primary,
                      onChanged: (val) => setModalState(() => isBedridden = val),
                    ),
                    SwitchListTile(
                      title: const Text('قادر على الحركة الخفيفة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                      value: canMove,
                      activeColor: c.primary,
                      onChanged: (val) => setModalState(() => canMove = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'الوزن التقريبي (كجم)',
                        labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary),
                        filled: true,
                        fillColor: c.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات طبية خاصة',
                        labelStyle: TextStyle(fontFamily: 'Cairo', color: c.textSecondary),
                        filled: true,
                        fillColor: c.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                        if (nameController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty ||
                            ageController.text.trim().isEmpty ||
                            label.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى ملء كافة الحقول الإلزامية')),
                          );
                          return;
                        }

                        Navigator.pop(context); // Close sheet
                        setState(() => _isLoading = true);

                        final payload = {
                          'label': label.trim(),
                          'name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'age': int.tryParse(ageController.text.trim()) ?? 0,
                          'gender': gender,
                          'relationship': patient?.relationship == 'self' ? 'self' : relationship,
                          'caseDefaults': {
                            'isBedridden': isBedridden,
                            'canMove': canMove,
                            'weight': double.tryParse(weightController.text.trim()),
                            'notes': notesController.text.trim(),
                          }
                        };

                        try {
                          Response res;
                          if (isEdit) {
                            res = await _api.dio.put('${Constants.savedPatients}/${patient.id}', data: payload);
                          } else {
                            res = await _api.dio.post(Constants.savedPatients, data: payload);
                          }

                          if (res.statusCode == 200 || res.statusCode == 201) {
                            _fetchPatients();
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('فشل حفظ البيانات الطبية. يرجى التحقق من المدخلات.')),
                          );
                          setState(() => _isLoading = false);
                        }
                      },
                      child: Text(
                        isEdit ? 'حفظ التعديلات' : 'إضافة المريض',
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

  Future<void> _deletePatient(SavedPatient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف المريض "${patient.label}" من قائمتك؟', style: const TextStyle(fontFamily: 'Cairo')),
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
        final res = await _api.dio.delete('${Constants.savedPatients}/${patient.id}');
        if (res.statusCode == 200) {
          _fetchPatients();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل حذف المريض من الملفات المحفوظة')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _makeDefault(SavedPatient patient) async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.dio.put('${Constants.savedPatients}/${patient.id}/default');
      if (res.statusCode == 200) {
        _fetchPatients();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تعيين المريض كافتراضي')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        title: Text(
          'المرضى المحفوظون',
          style: TextStyle(color: c.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: c.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: c.error, fontFamily: 'Cairo')),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchPatients,
                        child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                )
              : _patients.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد مرضى محفوظون في حسابك حالياً',
                        style: TextStyle(color: c.textSecondary, fontFamily: 'Cairo'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _patients.length,
                      itemBuilder: (context, index) {
                        final p = _patients[index];
                        return Card(
                          color: c.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: p.isDefault ? c.primary : c.borderLight,
                              width: p.isDefault ? 1.5 : 1,
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: c.primaryLight,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            p.label,
                                            style: TextStyle(
                                              color: c.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ),
                                        if (p.isDefault) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: c.successBg,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'افتراضي',
                                              style: TextStyle(
                                                color: c.success,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Cairo',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: c.textSecondary, size: 20),
                                          onPressed: () => _showAddEditBottomSheet(patient: p),
                                        ),
                                        if (p.relationship != 'self' && !p.isDefault)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                            onPressed: () => _deletePatient(p),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.phone_outlined, size: 14, color: c.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      p.phone,
                                      style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'Inter'),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.wc_rounded, size: 14, color: c.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${p.age} سنة · ${p.gender == 'male' ? 'ذكر' : 'أنثى'}',
                                      style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.family_restroom_outlined, size: 14, color: c.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      'صلة القرابة: ${_getRelationshipLabel(p.relationship)}',
                                      style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                                if (!p.isDefault) ...[
                                  const Divider(height: 20),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () => _makeDefault(p),
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
    );
  }
}

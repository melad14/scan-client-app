import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  final String registerToken;
  final String phone;

  const RegisterScreen({
    super.key,
    required this.registerToken,
    required this.phone,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _gender = 'male';
  bool _isLoading = false;
  String? _errorMessage;

  final _dio = Dio(BaseOptions(baseUrl: Constants.apiBaseUrl));

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final ageStr = _ageController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'الاسم مطلوب لإكمال التسجيل');
      return;
    }

    final age = int.tryParse(ageStr);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _dio.post(Constants.register, data: {
        'name': name,
        'age': age,
        'gender': _gender,
        'registerToken': widget.registerToken,
      });

      if (res.statusCode == 201 && res.data['success'] == true) {
        final accessToken = res.data['data']['accessToken'];
        final refreshToken = res.data['data']['refreshToken'];
        
        await StorageService.saveAccessToken(accessToken);
        await StorageService.saveRefreshToken(refreshToken);
        await StorageService.saveUserRole('patient');
        await StorageService.saveUserData(res.data['data']['user']);

        context.go('/');
      }
    } catch (e) {
      setState(() => _errorMessage = 'فشل إكمال عملية التسجيل. الرمز منتهي الصلاحية.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Welcome Header ───────────────────────────
              const Text(
                'أهلاً بك في سكان جو',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'تم التحقق من: ${widget.phone}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ─── Error ────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ─── Name Field ───────────────────────────────
              const Text(
                'الاسم بالكامل',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  hintText: 'مثال: محمد أحمد علي',
                ),
              ),
              const SizedBox(height: 20),

              // ─── Age Field ────────────────────────────────
              const Text(
                'العمر (اختياري)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.cake_outlined),
                  hintText: 'مثال: 55',
                ),
              ),
              const SizedBox(height: 24),

              // ─── Gender Selection ─────────────────────────
              const Text(
                'الجنس',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _gender = 'male'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _gender == 'male' ? AppColors.primaryLight : AppColors.surfaceVariant,
                          border: Border.all(
                            color: _gender == 'male' ? AppColors.primary : AppColors.border,
                            width: _gender == 'male' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.male_rounded,
                              color: _gender == 'male' ? AppColors.primary : AppColors.textMuted,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ذكر',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _gender == 'male' ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _gender = 'female'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _gender == 'female' ? AppColors.primaryLight : AppColors.surfaceVariant,
                          border: Border.all(
                            color: _gender == 'female' ? AppColors.primary : AppColors.border,
                            width: _gender == 'female' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.female_rounded,
                              color: _gender == 'female' ? AppColors.primary : AppColors.textMuted,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'أنثى',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _gender == 'female' ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ─── Submit Button ────────────────────────────
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('إنشاء الحساب ودخول التطبيق'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

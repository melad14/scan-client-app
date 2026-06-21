import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  final _dio = Dio(BaseOptions(baseUrl: Constants.apiBaseUrl));

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 11) {
      setState(() => _errorMessage = 'يرجى إدخال رقم هاتف صحيح');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _dio.post(Constants.sendOtp, data: {'phone': phone});
      if (res.statusCode == 200) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال رمز التحقق بنجاح')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'فشل إرسال رمز التحقق. يرجى المحاولة لاحقاً.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 6) {
      setState(() => _errorMessage = 'يرجى إدخال الرمز المكون من 6 أرقام');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _dio.post(Constants.verifyOtp, data: {
        'phone': phone,
        'otp': otp,
      });

      if (res.statusCode == 200 && res.data['success'] == true) {
        final isNew = res.data['data']['isNewUser'] as bool;
        if (isNew) {
          final regToken = res.data['data']['registerToken'];
          context.push('/register', extra: {
            'registerToken': regToken,
            'phone': phone,
          });
        } else {
          final accessToken = res.data['data']['accessToken'];
          final refreshToken = res.data['data']['refreshToken'];
          await StorageService.saveAccessToken(accessToken);
          await StorageService.saveRefreshToken(refreshToken);
          await StorageService.saveUserRole('patient');
          await StorageService.saveUserData(res.data['data']['user']);

          context.go('/');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'رمز التحقق غير صحيح أو منتهي الصلاحية');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 80),

                // ─── Logo Area ────────────────────────────────
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Title ────────────────────────────────────
                const Text(
                  'سكان جو',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDeep,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'خدمتك الطبية — في بيتك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 48),

                // ─── Error Message ────────────────────────────
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

                // ─── Phone Input ──────────────────────────────
                if (!_otpSent) ...[
                  const Text(
                    'رقم الهاتف',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.phone_rounded),
                      hintText: '01012345678',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('إرسال رمز التحقق'),
                  ),
                ] else ...[
                  // ─── OTP Input ────────────────────────────────
                  const Text(
                    'رمز التحقق',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تم إرسال رمز مكون من 6 أرقام إلى ${_phoneController.text}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 12,
                      fontFamily: 'Inter',
                    ),
                    maxLength: 6,
                    decoration: const InputDecoration(
                      hintText: '------',
                      counterText: '',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('التحقق وتسجيل الدخول'),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _otpSent = false),
                      child: const Text('تغيير رقم الهاتف'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

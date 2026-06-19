import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/services/storage_service.dart';

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
          // Redirect to registration screen with verification tokens
          final regToken = res.data['data']['registerToken'];
          context.push('/register', extra: {
            'registerToken': regToken,
            'phone': phone,
          });
        } else {
          // Existing user login
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أشعتك منزلية وخدمات تحاليل',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'احجز فحوصاتك الطبية وسيقوم فني متخصص بزيارتك بالمنزل',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 48),

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

              if (!_otpSent) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone),
                    hintText: 'رقم الهاتف (مثال: 01012345678)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('إرسال رمز التحقق (OTP)', style: TextStyle(fontSize: 16)),
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    hintText: 'أدخل الرمز المكون من 6 أرقام',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('التحقق وتسجيل الدخول', style: TextStyle(fontSize: 16)),
                ),
                TextButton(
                  onPressed: () => setState(() => _otpSent = false),
                  child: const Text('تغيير رقم الهاتف'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

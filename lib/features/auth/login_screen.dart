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

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _dio = Dio(BaseOptions(
    baseUrl: Constants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال اسم المستخدم وكلمة المرور');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final res = await _dio.post(Constants.patientLogin, data: {
        'username': username,
        'password': password,
      });

      if (res.statusCode == 200 && res.data['success'] == true) {
        await StorageService.saveAccessToken(res.data['data']['accessToken']);
        await StorageService.saveRefreshToken(res.data['data']['refreshToken']);
        await StorageService.saveUserRole('patient');
        await StorageService.saveUserData(res.data['data']['user']);
        if (mounted) context.go('/');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMsg = e.response?.data?['message'];

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        setState(() => _errorMessage = 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.');
      } else if (statusCode == 401) {
        setState(() => _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة');
      } else if (statusCode == 429) {
        setState(() => _errorMessage = 'محاولات كثيرة. انتظر قليلاً وحاول مرة أخرى.');
      } else if (statusCode != null && statusCode >= 500) {
        setState(() => _errorMessage = 'خطأ في الخادم. حاول مرة أخرى لاحقاً.');
      } else {
        setState(() => _errorMessage = serverMsg ?? 'فشل تسجيل الدخول. حاول مرة أخرى.');
      }
    } catch (_) {
      setState(() => _errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),

                    // ─── Logo ─────────────────────────────────────
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppColors.primaryGlow,
                        ),
                        child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 40),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Title ────────────────────────────────────
                    const Text(
                      'سكان جو',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                      child: const Text(
                        'خدماتك الطبية من باب بيتك',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ─── Form Card ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'تسجيل الدخول',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // ─── Error ───────────────────────────
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.errorBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.error.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: AppColors.error, fontSize: 13, height: 1.4),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _errorMessage = null),
                                    child: const Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ─── Username ────────────────────────
                          _FieldLabel(label: 'اسم المستخدم'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _usernameController,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                              hintText: 'اسم المستخدم أو البريد الإلكتروني',
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ─── Password ────────────────────────
                          _FieldLabel(label: 'كلمة المرور'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: AppColors.textPrimary),
                            onSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              hintText: '••••••••',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ─── Login Button ────────────────────
                          _GradientButton(
                            label: 'دخول',
                            isLoading: _isLoading,
                            onTap: _handleLogin,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Register Link ────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'ليس لديك حساب؟',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: ShaderMask(
                            shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                            child: const Text(
                              'إنشاء حساب جديد',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared Widget: Field Label ──────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
  );
}

// ── Shared Widget: Gradient Button ─────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _GradientButton({required this.label, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: isLoading ? null : AppColors.primaryGradient,
          color: isLoading ? AppColors.surfaceVariant : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading ? null : AppColors.primaryGlow,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
        ),
      ),
    );
  }
}

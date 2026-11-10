import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:dr_ray/core/utils/constants.dart';
import 'auth_glass_widgets.dart';

/// Forgot password — two steps on one screen:
///   1. username or email → POST /auth/patient/forgot-password (6-digit code by email)
///   2. code + new password → POST /auth/patient/reset-password → back to login
class ForgotPasswordScreen extends StatefulWidget {
  /// Pre-filled from the login screen's username field, if the user typed one
  final String? initialIdentifier;

  const ForgotPasswordScreen({super.key, this.initialIdentifier});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _identifierFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;
  String? _infoMessage;

  Timer? _resendTimer;
  int _resendSeconds = 0;

  late AnimationController _bgController;
  late AnimationController _pulseController;
  late AnimationController _entryController;
  late Animation<double> _bgAnim;
  late Animation<double> _fadeAnim;

  final _dio = Dio(BaseOptions(
    baseUrl: Constants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  @override
  void initState() {
    super.initState();
    _identifierController.text = widget.initialIdentifier?.trim() ?? '';
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.linear);
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entryController.forward();

    for (final f in [_identifierFocus, _codeFocus, _passwordFocus, _confirmFocus]) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _bgController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    for (final c in [_identifierController, _codeController, _passwordController, _confirmController]) {
      c.dispose();
    }
    for (final f in [_identifierFocus, _codeFocus, _passwordFocus, _confirmFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String _serverMessage(DioException e, String fallback) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.';
    }
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return fallback;
  }

  Future<void> _sendCode() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'أدخل اسم المستخدم أو البريد الإلكتروني');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _dio.post(Constants.forgotPassword, data: {'identifier': identifier});
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _infoMessage = res.data['message']?.toString() ?? 'تم إرسال رمز التحقق إلى بريدك الإلكتروني';
      });
      _startResendTimer();
      _codeFocus.requestFocus();
    } on DioException catch (e) {
      if (mounted) setState(() => _errorMessage = _serverMessage(e, 'تعذر إرسال الرمز. حاول مرة أخرى.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _errorMessage = 'أدخل الرمز المكون من 6 أرقام');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _errorMessage = 'كلمتا المرور غير متطابقتين');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _dio.post(Constants.resetPassword, data: {
        'identifier': _identifierController.text.trim(),
        'code': code,
        'newPassword': password,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.data['message']?.toString() ?? 'تم تغيير كلمة المرور بنجاح'),
        backgroundColor: const Color(0xFF1D9E75),
      ));
      context.go('/login');
    } on DioException catch (e) {
      if (mounted) setState(() => _errorMessage = _serverMessage(e, 'تعذر تغيير كلمة المرور. حاول مرة أخرى.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const mint = Color(0xFF2DDBA4);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            AuthAnimatedBackground(controller: _bgAnim, pulseController: _pulseController, size: size),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: size.height * 0.07),
                      const AuthBrandHeader(tagline: 'استعادة الوصول إلى حسابك', logoSize: 72),
                      SizedBox(height: size.height * 0.04),
                      AuthGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _codeSent ? 'تعيين كلمة مرور جديدة' : 'نسيت كلمة المرور؟',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _codeSent
                                  ? (_infoMessage ?? 'أدخل الرمز الذي وصلك على البريد الإلكتروني')
                                  : 'أدخل اسم المستخدم أو البريد الإلكتروني وسنرسل لك رمزاً لتغيير كلمة المرور',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
                            ),
                            const SizedBox(height: 24),
                            if (_errorMessage != null) ...[
                              AuthGlassErrorBanner(
                                message: _errorMessage!,
                                onClose: () => setState(() => _errorMessage = null),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (!_codeSent) ...[
                              AuthGlassInputField(
                                controller: _identifierController,
                                focusNode: _identifierFocus,
                                isFocused: _identifierFocus.hasFocus,
                                label: 'اسم المستخدم أو البريد',
                                hint: 'username أو name@mail.com',
                                icon: Icons.alternate_email_rounded,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                keyboardType: TextInputType.emailAddress,
                                onSubmitted: (_) => _sendCode(),
                              ),
                              const SizedBox(height: 28),
                              AuthGlowButton(label: 'إرسال الرمز', isLoading: _isLoading, onTap: _sendCode),
                            ] else ...[
                              AuthGlassInputField(
                                controller: _codeController,
                                focusNode: _codeFocus,
                                isFocused: _codeFocus.hasFocus,
                                label: 'رمز التحقق',
                                hint: '6 أرقام',
                                icon: Icons.pin_outlined,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                onSubmitted: (_) => _passwordFocus.requestFocus(),
                              ),
                              const SizedBox(height: 16),
                              AuthGlassInputField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                isFocused: _passwordFocus.hasFocus,
                                label: 'كلمة المرور الجديدة',
                                hint: '6 أحرف على الأقل',
                                icon: Icons.lock_outline_rounded,
                                obscureText: !_passwordVisible,
                                onSubmitted: (_) => _confirmFocus.requestFocus(),
                                suffixWidget: GestureDetector(
                                  onTap: () => setState(() => _passwordVisible = !_passwordVisible),
                                  child: Icon(
                                    _passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AuthGlassInputField(
                                controller: _confirmController,
                                focusNode: _confirmFocus,
                                isFocused: _confirmFocus.hasFocus,
                                label: 'تأكيد كلمة المرور',
                                hint: 'أعد كتابة كلمة المرور',
                                icon: Icons.lock_reset_rounded,
                                obscureText: !_passwordVisible,
                                onSubmitted: (_) => _resetPassword(),
                              ),
                              const SizedBox(height: 28),
                              AuthGlowButton(
                                label: 'تغيير كلمة المرور',
                                isLoading: _isLoading,
                                onTap: _resetPassword,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => setState(() {
                                              _codeSent = false;
                                              _errorMessage = null;
                                              _codeController.clear();
                                            }),
                                    child: Text('تغيير الحساب',
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                                  ),
                                  TextButton(
                                    onPressed: (_resendSeconds > 0 || _isLoading) ? null : _sendCode,
                                    child: Text(
                                      _resendSeconds > 0 ? 'إعادة الإرسال بعد $_resendSeconds ث' : 'إعادة إرسال الرمز',
                                      style: TextStyle(
                                        color: _resendSeconds > 0 ? Colors.white.withOpacity(0.4) : mint,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'العودة لتسجيل الدخول',
                          style: TextStyle(color: mint, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            // Back button on top of the scroll view so it always receives taps
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/login'),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/services/notification_service.dart';
import 'package:patient_app/core/theme/app_colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String userId;
  final String? email;

  const VerifyEmailScreen({
    super.key,
    required this.userId,
    this.email,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  Timer? _resendTimer;
  int _secondsRemaining = 60;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final _dio = Dio(BaseOptions(
    baseUrl: Constants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _startResendTimer();
  }

  @override
  void dispose() {
    _animController.dispose();
    _resendTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    final otp = _otpCode.trim();

    if (otp.length < 6) {
      setState(() => _errorMessage = 'يرجى إدخال الرمز المكون من 6 أرقام بالكامل');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await _dio.post(Constants.verifyEmail, data: {
        'userId': widget.userId,
        'otp': otp,
      });

      if (res.statusCode == 200 && res.data['success'] == true) {
        final data = res.data['data'];
        if (data['accessToken'] != null) {
          await StorageService.saveAccessToken(data['accessToken']);
          await StorageService.saveRefreshToken(data['refreshToken']);
          await StorageService.saveUserRole('patient');
          await StorageService.saveUserData(data['user']);

          await NotificationService.registerDeviceToken();
        }

        if (mounted) {
          context.go('/');
        }
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      String? serverMsg;
      if (e.response?.data is Map) {
        serverMsg = e.response?.data['message']?.toString();
      } else if (e.response?.data is String) {
        serverMsg = e.response?.data as String;
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        setState(() => _errorMessage = 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.');
      } else if (statusCode == 400 && serverMsg != null) {
        setState(() => _errorMessage = serverMsg);
      } else {
        setState(() => _errorMessage = serverMsg ?? 'فشل تفعيل الحساب. حاول مرة أخرى.');
      }
    } catch (_) {
      setState(() => _errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResend() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await _dio.post(Constants.resendVerification, data: {
        'userId': widget.userId,
      });

      if (res.statusCode == 200 && res.data['success'] == true) {
        setState(() => _successMessage = 'تم إعادة إرسال رمز التحقق إلى بريدك الإلكتروني بنجاح');
        _startResendTimer();
      }
    } on DioException catch (e) {
      String? serverMsg;
      if (e.response?.data is Map) {
        serverMsg = e.response?.data['message']?.toString();
      }
      setState(() => _errorMessage = serverMsg ?? 'فشل إعادة إرسال الرمز. حاول مرة أخرى لاحقاً.');
    } catch (_) {
      setState(() => _errorMessage = 'حدث خطأ أثناء إعادة إرسال الرمز.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _handleBackNavigation(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation(context);
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // ─── Header ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _handleBackNavigation(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary, size: 18),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'تفعيل الحساب',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // ─── Body Content ──────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Icon Header
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: c.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.mark_email_read_rounded, color: c.primary, size: 36),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'رمز التحقق من البريد',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          widget.email != null
                              ? 'أدخل رمز التحقق المكون من 6 أرقام الذي أرسلناه إلى:\n${widget.email}'
                              : 'أدخل رمز التحقق المكون من 6 أرقام الذي أرسلناه إلى بريدك الإلكتروني المسجل.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                        ),
                        const SizedBox(height: 32),

                        // ─── Error Message ──────────────────────────
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: c.errorBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: c.error, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: c.error, fontSize: 13, height: 1.4),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _errorMessage = null),
                                  child: Icon(Icons.close_rounded, color: c.error, size: 18),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ─── Success Message ────────────────────────
                        if (_successMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: c.successBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.success.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: c.success, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: TextStyle(color: c.success, fontSize: 13, height: 1.4),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _successMessage = null),
                                  child: Icon(Icons.close_rounded, color: c.success, size: 18),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ─── 6-Digit OTP Inputs ─────────────────────
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width: 46,
                                height: 56,
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    fillColor: c.surfaceVariant,
                                    filled: true,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: c.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: c.primary, width: 2),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      if (index < 5) {
                                        _focusNodes[index + 1].requestFocus();
                                      } else {
                                        _focusNodes[index].unfocus();
                                        _handleVerify();
                                      }
                                    } else {
                                      if (index > 0) {
                                        _focusNodes[index - 1].requestFocus();
                                      }
                                    }
                                  },
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // ─── Verify Button ──────────────────────────
                        GestureDetector(
                          onTap: _isLoading ? null : _handleVerify,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: c.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : const Text(
                                      'تأكيد وتفعيل الحساب',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─── Resend Timer Button ────────────────────
                        Center(
                          child: _isResending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : TextButton(
                                  onPressed: _secondsRemaining == 0 ? _handleResend : null,
                                  child: Text(
                                    _secondsRemaining > 0
                                        ? 'إعادة إرسال الكود ($_secondsRemainingث)'
                                        : 'إعادة إرسال الرمز بريدياً',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _secondsRemaining == 0 ? c.primary : c.textMuted,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

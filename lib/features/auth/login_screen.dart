import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:dr_ray/core/utils/constants.dart';
import 'package:dr_ray/core/services/storage_service.dart';
import 'package:dr_ray/core/services/notification_service.dart';
import 'package:dr_ray/core/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;

  late AnimationController _entryController;
  late AnimationController _bgController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _logoScaleAnim;
  late Animation<double> _bgAnim;

  final _dio = Dio(BaseOptions(
    baseUrl: Constants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.linear);
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic)));
    _logoScaleAnim = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)));
    _entryController.forward();

    _usernameFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _entryController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
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
        await NotificationService.registerDeviceToken();
        if (mounted) context.go('/');
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
      } else if (statusCode == 403 && e.response?.data is Map && e.response?.data['code'] == 'EMAIL_NOT_VERIFIED') {
        final data = e.response?.data['data'];
        final userId = data?['userId']?.toString() ?? '';
        final email = data?['email']?.toString();
        if (mounted && userId.isNotEmpty) {
          context.go('/verify-email', extra: {'userId': userId, 'email': email});
        } else {
          setState(() => _errorMessage = serverMsg ?? 'البريد الإلكتروني غير مفعّل.');
        }
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
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF061A13),
        body: Stack(
          children: [
            // ── Animated Background ─────────────────────────────
            _AnimatedBackground(controller: _bgAnim, pulseController: _pulseController, size: size),

            // ── Main Content ────────────────────────────────────
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: size.height * 0.07),

                          // ── Logo & Brand ──────────────────────
                          ScaleTransition(
                            scale: _logoScaleAnim,
                            child: Column(
                              children: [
                                // Glowing Logo
                                Container(
                                  width: 90, height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2DDBA4), Color(0xFF1D9E75)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF1D9E75).withOpacity(0.5), blurRadius: 30, spreadRadius: 4),
                                      BoxShadow(color: const Color(0xFF1D9E75).withOpacity(0.2), blurRadius: 60, spreadRadius: 10),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/icon/app_icon.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.medical_services_rounded,
                                        color: Colors.white, size: 44,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Brand Name
                                const Text(
                                  'Dr Ray',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                    shadows: [Shadow(color: Color(0xFF1D9E75), blurRadius: 20)],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'خدماتك الطبية من باب بيتك',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.6),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: size.height * 0.06),

                          // ── Glass Form Card ───────────────────
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Form Title
                                    const Text(
                                      'تسجيل الدخول',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontFamily: 'Cairo',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'مرحباً بعودتك 👋',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.5),
                                        fontFamily: 'Cairo',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 28),

                                    // ── Error Banner ─────────────
                                    if (_errorMessage != null) ...[
                                      _GlassErrorBanner(message: _errorMessage!, onClose: () => setState(() => _errorMessage = null)),
                                      const SizedBox(height: 20),
                                    ],

                                    // ── Username Field ───────────
                                    _GlassInputField(
                                      controller: _usernameController,
                                      focusNode: _usernameFocus,
                                      label: 'اسم المستخدم',
                                      hint: 'اسم المستخدم أو البريد الإلكتروني',
                                      icon: Icons.alternate_email_rounded,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.right,
                                      isFocused: _usernameFocus.hasFocus,
                                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                                    ),
                                    const SizedBox(height: 16),

                                    // ── Password Field ───────────
                                    _GlassInputField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      label: 'كلمة المرور',
                                      hint: '••••••••',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: !_passwordVisible,
                                      isFocused: _passwordFocus.hasFocus,
                                      onSubmitted: (_) => _handleLogin(),
                                      suffixWidget: GestureDetector(
                                        onTap: () => setState(() => _passwordVisible = !_passwordVisible),
                                        child: Icon(
                                          _passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: Colors.white.withOpacity(0.5),
                                          size: 20,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 32),

                                    // ── Login Button ─────────────
                                    _GlowButton(
                                      label: 'دخول',
                                      isLoading: _isLoading,
                                      onTap: _handleLogin,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Register Link ─────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'ليس لديك حساب؟',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                              ),
                              TextButton(
                                onPressed: () => context.push('/register'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2DDBA4),
                                ),
                                child: const Text(
                                  'إنشاء حساب جديد',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2DDBA4),
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
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

// ────────────────────────────────────────────────────────────────────
// Animated Background with floating orbs
// ────────────────────────────────────────────────────────────────────
class _AnimatedBackground extends StatelessWidget {
  final Animation<double> controller;
  final Animation<double> pulseController;
  final Size size;

  const _AnimatedBackground({
    required this.controller,
    required this.pulseController,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, pulseController]),
      builder: (_, __) {
        final t = controller.value;
        final p = pulseController.value;
        return Stack(
          children: [
            // Deep dark background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF061A13), Color(0xFF0A2518), Color(0xFF061A13)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Orb 1 — teal
            Positioned(
              top: size.height * 0.08 + math.sin(t * 2 * math.pi) * 20,
              right: -size.width * 0.15 + math.cos(t * 2 * math.pi) * 10,
              child: _Orb(
                size: size.width * 0.7,
                color: const Color(0xFF1D9E75).withOpacity(0.18 + p * 0.06),
                blurRadius: 80,
              ),
            ),
            // Orb 2 — emerald
            Positioned(
              bottom: size.height * 0.15 + math.cos(t * 2 * math.pi) * 25,
              left: -size.width * 0.2 + math.sin(t * 2 * math.pi) * 15,
              child: _Orb(
                size: size.width * 0.6,
                color: const Color(0xFF085041).withOpacity(0.22 + p * 0.04),
                blurRadius: 70,
              ),
            ),
            // Orb 3 — small accent
            Positioned(
              top: size.height * 0.4 + math.sin(t * 2 * math.pi + 1) * 30,
              left: size.width * 0.6 + math.cos(t * 2 * math.pi + 1) * 10,
              child: _Orb(
                size: size.width * 0.4,
                color: const Color(0xFF2DDBA4).withOpacity(0.08 + p * 0.04),
                blurRadius: 60,
              ),
            ),
            // Subtle grid pattern
            CustomPaint(
              size: size,
              painter: _GridPainter(opacity: 0.04),
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double blurRadius;

  const _Orb({required this.size, required this.color, required this.blurRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: blurRadius, spreadRadius: blurRadius * 0.3)],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double opacity;
  _GridPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────────────
// Glass Input Field
// ────────────────────────────────────────────────────────────────────
class _GlassInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final bool isFocused;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final Widget? suffixWidget;
  final ValueChanged<String>? onSubmitted;

  const _GlassInputField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isFocused,
    this.obscureText = false,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.suffixWidget,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.65),
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFF1D9E75).withOpacity(0.8)
                  : Colors.white.withOpacity(0.12),
              width: isFocused ? 1.5 : 1,
            ),
            boxShadow: isFocused
                ? [BoxShadow(color: const Color(0xFF1D9E75).withOpacity(0.2), blurRadius: 12, spreadRadius: 0)]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                textDirection: textDirection,
                textAlign: textAlign,
                onSubmitted: onSubmitted,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontFamily: 'Cairo',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Cairo'),
                  prefixIcon: Icon(icon, color: isFocused ? const Color(0xFF1D9E75) : Colors.white.withOpacity(0.4), size: 20),
                  suffixIcon: suffixWidget != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixWidget) : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Glowing CTA Button
// ────────────────────────────────────────────────────────────────────
class _GlowButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _GlowButton({required this.label, required this.isLoading, required this.onTap});

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _pressed
                  ? [const Color(0xFF16755A), const Color(0xFF1D9E75)]
                  : [const Color(0xFF2DDBA4), const Color(0xFF1D9E75), const Color(0xFF085041)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.isLoading
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF1D9E75).withOpacity(_pressed ? 0.2 : 0.45),
                      blurRadius: _pressed ? 8 : 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF1D9E75).withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'دخول',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_back_rounded, color: Colors.white.withOpacity(0.8), size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Glass Error Banner
// ────────────────────────────────────────────────────────────────────
class _GlassErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _GlassErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD44245).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD44245).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6E), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFFF9B9D),
                    fontSize: 13,
                    height: 1.4,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, color: Color(0xFFFF6B6E), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

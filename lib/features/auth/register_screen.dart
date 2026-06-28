import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:patient_app/core/utils/constants.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/services/notification_service.dart';
import 'package:patient_app/core/theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController       = TextEditingController();
  final TextEditingController _nameController           = TextEditingController();
  final TextEditingController _emailController          = TextEditingController();
  final TextEditingController _passwordController       = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final _dio = Dio(BaseOptions(
    baseUrl: Constants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) => RegExp(r'^\S+@\S+\.\S+$').hasMatch(email);
  bool _isValidUsername(String u) => RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(u);

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm  = _confirmPasswordController.text.trim();

    if (username.isEmpty)                      { setState(() => _errorMessage = 'اسم المستخدم مطلوب'); return; }
    if (!_isValidUsername(username))           { setState(() => _errorMessage = 'اسم المستخدم: حروف وأرقام فقط، 3 أحرف كحد أدنى'); return; }
    if (name.isEmpty)                          { setState(() => _errorMessage = 'الاسم بالكامل مطلوب'); return; }
    if (email.isEmpty || !_isValidEmail(email)){ setState(() => _errorMessage = 'يرجى إدخال بريد إلكتروني صحيح'); return; }
    if (password.length < 6)                   { setState(() => _errorMessage = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'); return; }
    if (password != confirm)                   { setState(() => _errorMessage = 'كلمتا المرور غير متطابقتين'); return; }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final res = await _dio.post(Constants.patientRegister, data: {
        'username': username,
        'name':     name,
        'email':    email,
        'password': password,
      });

      if (res.statusCode == 201 && res.data['success'] == true) {
        await StorageService.saveAccessToken(res.data['data']['accessToken']);
        await StorageService.saveRefreshToken(res.data['data']['refreshToken']);
        await StorageService.saveUserRole('patient');
        await StorageService.saveUserData(res.data['data']['user']);
        
        // Register Push Notification Token
        await NotificationService.registerDeviceToken();

        if (mounted) context.go('/');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMsg  = e.response?.data?['message'];

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        setState(() => _errorMessage = 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.');
      } else if (statusCode == 400 && serverMsg != null) {
        setState(() => _errorMessage = serverMsg);
      } else if (statusCode == 429) {
        setState(() => _errorMessage = 'محاولات كثيرة. انتظر قليلاً وحاول مرة أخرى.');
      } else {
        setState(() => _errorMessage = serverMsg ?? 'فشل إنشاء الحساب. حاول مرة أخرى.');
      }
    } catch (_) {
      setState(() => _errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;

    return Scaffold(
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
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40, height: 40,
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
                        'حساب جديد',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // ─── Form ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Welcome tag
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: c.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            'أهلاً بك في سكان جو ✨',
                            style: TextStyle(color: c.primary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Error ─────────────────────────────────
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
                              Expanded(child: Text(_errorMessage!,
                                  style: TextStyle(color: c.error, fontSize: 13, height: 1.4))),
                              GestureDetector(
                                onTap: () => setState(() => _errorMessage = null),
                                child: Icon(Icons.close_rounded, color: c.error, size: 18),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ─── Fields ────────────────────────────────
                      _buildField('اسم المستخدم', Icons.alternate_email_rounded, _usernameController,
                          hint: 'مثال: ahmed_123', ltr: true, colors: c),
                      const SizedBox(height: 16),

                      _buildField('الاسم بالكامل', Icons.person_outline_rounded, _nameController,
                          hint: 'مثال: محمد أحمد', colors: c),
                      const SizedBox(height: 16),

                      _buildField('البريد الإلكتروني', Icons.email_outlined, _emailController,
                          hint: 'example@email.com', ltr: true,
                          keyboardType: TextInputType.emailAddress, colors: c),
                      const SizedBox(height: 16),

                      _buildPasswordField('كلمة المرور', _passwordController, _passwordVisible,
                          () => setState(() => _passwordVisible = !_passwordVisible), colors: c),
                      const SizedBox(height: 4),
                      Text('6 أحرف على الأقل', style: TextStyle(fontSize: 11, color: c.textMuted)),
                      const SizedBox(height: 16),

                      _buildPasswordField('تأكيد كلمة المرور', _confirmPasswordController, _confirmPasswordVisible,
                          () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible), colors: c),
                      const SizedBox(height: 28),

                      // ─── Register Button ────────────────────────
                      _SolidButton(
                        label: 'إنشاء الحساب والدخول',
                        isLoading: _isLoading,
                        primary: c.primary,
                        onTap: _handleRegister,
                      ),
                      const SizedBox(height: 20),

                      // ─── Login Link ─────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('لديك حساب بالفعل؟',
                              style: TextStyle(color: c.textSecondary, fontSize: 14)),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text(
                              'تسجيل الدخول',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    IconData icon,
    TextEditingController ctrl, {
    String? hint,
    bool ltr = false,
    TextInputType? keyboardType,
    required AppColorTokens colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
          textAlign: TextAlign.right,
          autocorrect: false,
          keyboardType: keyboardType,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(prefixIcon: Icon(icon), hintText: hint),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController ctrl,
    bool visible,
    VoidCallback toggle, {
    required AppColorTokens colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: !visible,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            hintText: '••••••••',
            suffixIcon: IconButton(
              icon: Icon(
                visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: colors.textMuted, size: 20,
              ),
              onPressed: toggle,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Solid Teal Button ───────────────────────────────────────────
class _SolidButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final Color primary;
  final VoidCallback onTap;
  const _SolidButton({required this.label, required this.isLoading, required this.primary, required this.onTap});
  @override State<_SolidButton> createState() => _SolidButtonState();
}

class _SolidButtonState extends State<_SolidButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 54,
        decoration: BoxDecoration(
          color: widget.isLoading
              ? widget.primary.withOpacity(0.6)
              : _pressed ? widget.primary.withOpacity(0.85) : widget.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: widget.isLoading ? [] : [
            BoxShadow(color: widget.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(height: 22, width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
        ),
      ),
    );
  }
}

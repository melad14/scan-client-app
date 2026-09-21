import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:dr_ray/core/utils/constants.dart';
import 'package:dr_ray/core/services/storage_service.dart';
import 'package:dr_ray/core/services/notification_service.dart';
import 'package:dr_ray/core/theme/app_colors.dart';
import 'package:dr_ray/core/utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController       = TextEditingController();
  final TextEditingController _nameController           = TextEditingController();
  final TextEditingController _emailController          = TextEditingController();
  final TextEditingController _phoneController          = TextEditingController();
  final TextEditingController _ageController            = TextEditingController();
  final TextEditingController _passwordController       = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String _selectedGender = 'male';
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _errorMessage;

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
    _phoneController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Per-field errors, shown under the field they belong to.
  final Map<String, String?> _fieldErrors = {};

  void _clearFieldError(String key) {
    if (_fieldErrors[key] != null) setState(() => _fieldErrors[key] = null);
  }

  /// Fills [_fieldErrors] and returns true when every field is valid.
  /// All fields are checked at once so the user sees everything that is wrong.
  bool _validateAll() {
    final password = _passwordController.text;
    final errors = <String, String?>{
      'username': validateUsername(_usernameController.text),
      'name': validateFullName(_nameController.text),
      'email': validateEmail(_emailController.text),
      'phone': validateEgyptPhone(_phoneController.text),
      'age': validateAge(_ageController.text),
      'password': validatePassword(password),
      'confirm': password != _confirmPasswordController.text
          ? 'كلمتا المرور غير متطابقتين'
          : null,
    };
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
      _errorMessage = null;
    });
    return errors.values.every((e) => e == null);
  }

  Future<void> _handleRegister() async {
    if (!_validateAll()) return;

    final username = _usernameController.text.trim();
    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim();
    final phone    = normaliseEgyptPhone(_phoneController.text);
    final age      = _ageController.text.trim();
    final password = _passwordController.text.trim();

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final res = await _dio.post(Constants.patientRegister, data: {
        'username': username,
        'name':     name,
        'email':    email,
        'phone':    phone,
        'age':      int.parse(age),
        'gender':   _selectedGender,
        'password': password,
      });

      if (res.statusCode == 201 && res.data['success'] == true) {
        final userId = res.data['data']['userId']?.toString() ?? '';
        final userEmail = res.data['data']['email']?.toString() ?? email;

        if (mounted) {
          context.go('/verify-email', extra: {'userId': userId, 'email': userEmail});
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
        // Put "already registered" errors under the field they belong to
        // instead of a generic banner the user has to map themselves.
        final key = serverMsg.contains('اسم المستخدم')
            ? 'username'
            : serverMsg.contains('البريد')
                ? 'email'
                : serverMsg.contains('هاتف')
                    ? 'phone'
                    : null;
        setState(() {
          if (key != null) {
            _fieldErrors[key] = serverMsg;
          } else {
            _errorMessage = serverMsg;
          }
        });
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
                            'أهلاً بك في Dr Ray ✨',
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
                          hint: 'مثال: ahmed_123', ltr: true, colors: c, errorKey: 'username'),
                      const SizedBox(height: 16),

                      _buildField('الاسم بالكامل', Icons.person_outline_rounded, _nameController,
                          hint: 'مثال: محمد أحمد', colors: c, errorKey: 'name'),
                      const SizedBox(height: 16),

                      _buildField('البريد الإلكتروني', Icons.email_outlined, _emailController,
                          hint: 'example@email.com', ltr: true,
                          keyboardType: TextInputType.emailAddress, colors: c, errorKey: 'email'),
                      const SizedBox(height: 16),

                      _buildField('رقم الهاتف', Icons.phone_outlined, _phoneController,
                          hint: 'مثال: 01012345678', ltr: true,
                          keyboardType: TextInputType.phone, colors: c, errorKey: 'phone'),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildField('العمر', Icons.cake_outlined, _ageController,
                                hint: 'مثال: 25', ltr: true,
                                keyboardType: TextInputType.number, colors: c, errorKey: 'age'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('الجنس', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: c.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: c.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedGender,
                                      isExpanded: true,
                                      dropdownColor: c.surfaceElevated,
                                      style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: c.textPrimary),
                                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                                      onChanged: (v) { if (v != null) setState(() => _selectedGender = v); },
                                      items: const [
                                        DropdownMenuItem(value: 'male', child: Text('ذكر')),
                                        DropdownMenuItem(value: 'female', child: Text('أنثى')),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildPasswordField('كلمة المرور', _passwordController, _passwordVisible,
                          () => setState(() => _passwordVisible = !_passwordVisible), colors: c, errorKey: 'password'),
                      const SizedBox(height: 4),
                      Text('6 أحرف على الأقل', style: TextStyle(fontSize: 11, color: c.textMuted)),
                      const SizedBox(height: 16),

                      _buildPasswordField('تأكيد كلمة المرور', _confirmPasswordController, _confirmPasswordVisible,
                          () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible), colors: c, errorKey: 'confirm'),
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

  /// Small red message rendered directly under a field.
  Widget _fieldError(String? msg, AppColorTokens colors) {
    if (msg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: colors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(msg,
                style: TextStyle(fontSize: 11.5, color: colors.error, fontFamily: 'Cairo', height: 1.4)),
          ),
        ],
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
    String? errorKey,
  }) {
    final err = errorKey == null ? null : _fieldErrors[errorKey];
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
          onChanged: errorKey == null ? null : (_) => _clearFieldError(errorKey),
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hint,
            enabledBorder: err == null
                ? null
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.error, width: 1.4),
                  ),
          ),
        ),
        _fieldError(err, colors),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController ctrl,
    bool visible,
    VoidCallback toggle, {
    required AppColorTokens colors,
    String? errorKey,
  }) {
    final err = errorKey == null ? null : _fieldErrors[errorKey];
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
          onChanged: errorKey == null ? null : (_) => _clearFieldError(errorKey),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            hintText: '••••••••',
            enabledBorder: err == null
                ? null
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.error, width: 1.4),
                  ),
            suffixIcon: IconButton(
              icon: Icon(
                visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: colors.textMuted, size: 20,
              ),
              onPressed: toggle,
            ),
          ),
        ),
        _fieldError(err, colors),
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
